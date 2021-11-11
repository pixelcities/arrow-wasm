#include <iostream>

#include <arrow/io/api.h>
#include <arrow/ipc/api.h>
#include <arrow/pretty_print.h>
#include <arrow/result.h>
#include <arrow/status.h>
#include <arrow/table.h>
#include <arrow/filesystem/s3fs.h>
#include <arrow/dataset/dataset.h>
#include <arrow/dataset/scanner.h>
#include <arrow/dataset/discovery.h>
#include <arrow/dataset/file_parquet.h>
#include <parquet/arrow/reader.h>
#include <parquet/arrow/writer.h>
#include <arrow/csv/api.h>
#include <arrow/api.h>

#include <emscripten/bind.h>

#define ERROR(msg) std::cerr << msg << std::endl; return;


using namespace emscripten;
using arrow::Status;

void load_csv(std::string csv, std::string path) {
  std::cerr << csv << std::endl;

  auto input = std::make_shared<arrow::io::BufferReader>(csv);
  auto read_options = arrow::csv::ReadOptions::Defaults();
  auto parse_options = arrow::csv::ParseOptions::Defaults();
  auto convert_options = arrow::csv::ConvertOptions::Defaults();

  read_options.use_threads = false;

  auto maybe_reader = arrow::csv::TableReader::Make(arrow::io::default_io_context(),
      input, read_options, parse_options, convert_options);

  if (!maybe_reader.ok()) {
    ERROR(maybe_reader.status().ToString());
  }

  std::shared_ptr<arrow::csv::TableReader> reader = *maybe_reader;

  auto maybe_table = reader->Read();
  if (!maybe_table.ok()) {
    ERROR(maybe_table.status().ToString());
  }

  // save to virtual filesystem
  std::shared_ptr<arrow::io::OutputStream> sink = *arrow::io::FileOutputStream::Open(path);

  auto table = *maybe_table;
  auto write_options = arrow::ipc::IpcWriteOptions::Defaults();
  auto writer = *arrow::ipc::MakeFileWriter(sink, table->schema(), write_options);

  writer->WriteTable(*table, -1);
  writer->Close();
  sink->Close();
}


void read_remote_parquet(std::string in_path, std::string out_path, std::string access_key, std::string secret_key, std::string session_token, const val &keys) {

  /* Pull in key array */
  std::vector<std::string> keymap = emscripten::vecFromJSArray<std::string>(keys); // ["footer", "kid0", "key0", "column1", "kid1", "key1", ...]


  /* S3 filesystem setup */
  auto options = arrow::fs::S3Options::FromAccessKey(access_key, secret_key, session_token);
  options.region = "eu-west-1";
  options.background_writes = false;

  arrow::fs::S3GlobalOptions g_options{arrow::fs::S3LogLevel::Info};
  arrow::fs::InitializeS3(g_options);

  auto maybe_fs = arrow::fs::S3FileSystem::Make(options);
  if (!maybe_fs.ok()) {
    ERROR(maybe_fs.status().ToString());
  }
  std::shared_ptr<arrow::fs::S3FileSystem> fs = *maybe_fs;


  /* Decryption properties */
  if (keymap.size() < 3) {
    ERROR("Invalid keymap for parquet decryption configuration");
  }

  std::string footer = keymap[0];
  std::string footer_kid = keymap[1];
  std::string footer_key = keymap[2];

  if (footer != "__FOOTER") {
    ERROR("Invalid footer constant");
  }

  std::shared_ptr<parquet::StringKeyIdRetriever> str_key_retriever = std::make_shared<parquet::StringKeyIdRetriever>();
  std::vector<std::string> columns;

  for (int i = 3; i < keymap.size(); i+=3) {
    std::string column = keymap[i];
    std::string kid = keymap[i+1];
    std::string key = keymap[i+2];

    columns.push_back(column);
    str_key_retriever->PutKey(kid, key);
  }
  str_key_retriever->PutKey(footer_kid, footer_key);

  std::shared_ptr<parquet::DecryptionKeyRetriever> key_retriever = std::static_pointer_cast<parquet::StringKeyIdRetriever>(str_key_retriever);
  parquet::FileDecryptionProperties::Builder decryption_builder;
  std::shared_ptr<parquet::FileDecryptionProperties> decryption_properties = decryption_builder.key_retriever(key_retriever)->build();


  /* Add decryption configuration to reader properties */
  parquet::ReaderProperties reader_properties = parquet::default_reader_properties();
  reader_properties.file_decryption_properties(decryption_properties);

  parquet::ArrowReaderProperties arrow_properties;
  arrow_properties.set_use_threads(false);


  /* Read the table as a dataset */
  std::shared_ptr<arrow::dataset::FileFormat> format = std::make_shared<arrow::dataset::ParquetFileFormat>(reader_properties);

  arrow::fs::FileSelector selector;
  selector.base_dir = in_path;

  // TODO: no need for the parent dataset really, this just adds network overhead
  auto factory = arrow::dataset::FileSystemDatasetFactory::Make(fs, selector, format, arrow::dataset::FileSystemFactoryOptions()).ValueOrDie();
  std::shared_ptr<arrow::dataset::Dataset> dataset = *factory->Finish();

  std::vector<std::shared_ptr<arrow::ChunkedArray>> chunks;
  std::vector<std::shared_ptr<arrow::Field>> fields;

  /* Construct a table by manually going over each fragment
   *
   * We actually allow splitting our tables by column, but when merging
   * these back arrow obviously treats them as seperate row groups:
   *
   * | a | b | c | d |
   * | - | - | - | - |
   * | 1 | 2 |   |   |
   * | 5 | 6 |   |   |
   * |   |   | 3 | 4 |
   * |   |   | 7 | 8 |
   *
   * By extracting each column chunk from the (fragment) table we can guide
   * the merge process ourselves.
   *
   * Note that this assumes that fragments are whole parquet files.
   */
  for (auto maybe_fragment : *dataset->GetFragments()) {
    std::shared_ptr<arrow::dataset::Fragment> fragment = *maybe_fragment;
    std::shared_ptr<arrow::Schema> f_schema = *fragment->ReadPhysicalSchema();

    // scan projection fails when passing nonexisting column names
    std::vector<std::string> f_columns;
    for (const auto& col : columns) {
      if (f_schema->GetFieldByName(col) != nullptr) {
        f_columns.push_back(col);
      }
    }

    if (!f_columns.size()) {
      continue;
    }

    std::shared_ptr<arrow::dataset::ScanOptions> scan_options = std::make_shared<arrow::dataset::ScanOptions>();
    auto scan_builder = arrow::dataset::ScannerBuilder(f_schema, fragment, scan_options);
    scan_builder.Project(f_columns);

    auto scanner = *scan_builder.Finish();
    std::shared_ptr<arrow::Table> f_table = *scanner->ToTable();

    for (auto field : f_table->fields()) {
      fields.push_back(field);
    }

    for (auto column : f_table->columns()) {
      chunks.push_back(column);
    }
  }

  auto schema = std::make_shared<arrow::Schema>(fields);
  auto table = arrow::Table::Make(schema, chunks, -1);
}

void write_remote_parquet(std::string in_path, std::string out_path, std::string access_key, std::string secret_key, std::string session_token, const val &keys) {

  /* Pull in key array */
  std::vector<std::string> keymap = emscripten::vecFromJSArray<std::string>(keys); // ["footer", "kid0", "key0", "column1", "kid1", "key1", ...]


  /* Build table from IPC file */
  auto source = *arrow::io::ReadableFile::Open(in_path);

  auto read_options = arrow::ipc::IpcReadOptions::Defaults();
  auto reader = *arrow::ipc::RecordBatchFileReader::Open(source, read_options);

  std::vector<std::shared_ptr<arrow::RecordBatch>> batches;
  for (int i = 0; i < reader->num_record_batches(); ++i) {
    batches.push_back(*reader->ReadRecordBatch(i));
  }
  auto table = *arrow::Table::FromRecordBatches(batches);


  /* S3 filesystem setup */
  auto options = arrow::fs::S3Options::FromAccessKey(access_key, secret_key, session_token);
  options.region = "eu-west-1";
  options.background_writes = false;

  arrow::fs::S3GlobalOptions g_options{arrow::fs::S3LogLevel::Info};
  arrow::fs::InitializeS3(g_options);

  auto maybe_fs = arrow::fs::S3FileSystem::Make(options);
  if (!maybe_fs.ok()) {
    std::cerr << "ERROR!" << std::endl;
    std::cerr << maybe_fs.status().ToString() << std::endl;
  }
  std::shared_ptr<arrow::fs::S3FileSystem> fs = *maybe_fs;

  std::shared_ptr<arrow::io::OutputStream> sink = *(fs->OpenOutputStream(out_path));


  /* Encryption properties */
  if (keymap.size() / 3 != table->num_columns() + 1) {
    ERROR("Invalid keymap for parquet encryption configuration");
  }

  std::string footer = keymap[0];
  std::string footer_kid = keymap[1];
  std::string footer_key = keymap[2];

  if (footer != "__FOOTER") {
    ERROR("Invalid footer constant");
  }

  parquet::FileEncryptionProperties::Builder file_encryption_builder(footer_key);

  std::map<std::string, std::shared_ptr<parquet::ColumnEncryptionProperties>> encryption_cols;
  for (int i = 3; i < keymap.size(); i+=3) {
    std::string column = keymap[i];
    std::string kid = keymap[i+1];
    std::string key = keymap[i+2];

    parquet::ColumnEncryptionProperties::Builder encryption_col_builder(column);
    encryption_col_builder.key(key)->key_id(kid);
    encryption_cols[column] = encryption_col_builder.build();
  }

  /* Add encryption configuration to writer properties */
  parquet::WriterProperties::Builder builder;
  builder.encryption(file_encryption_builder.footer_key_metadata(footer_kid)->encrypted_columns(encryption_cols)->build());

  std::shared_ptr<parquet::WriterProperties> writer_properties = builder.build();
  auto arrow_properties = parquet::default_arrow_writer_properties();


  /* Write the table */
  parquet::arrow::WriteTable(*table, arrow::default_memory_pool(), sink, writer_properties->max_row_group_length(), writer_properties, arrow_properties);
}

EMSCRIPTEN_BINDINGS(my_module) {
    function("load_csv", &load_csv);
    function("write_remote_parquet", &write_remote_parquet);
    function("read_remote_parquet", &read_remote_parquet);
}

int main() {
  return 0;
}
