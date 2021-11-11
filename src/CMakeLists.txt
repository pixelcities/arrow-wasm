cmake_minimum_required(VERSION 3.0)

project(ArrowWasm)

option(ARROW_LINK_SHARED "Link to the Arrow shared library" OFF)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_BUILD_TYPE Release)

add_executable(arrow_wasm arrow_wasm.cc utils/arrow_single_threaded_reader.cc)

include_directories(./)

target_link_libraries(arrow_wasm PRIVATE /build/arrow/release/libarrow.a)
target_link_libraries(arrow_wasm PRIVATE /build/arrow/release/libparquet.a)
target_link_libraries(arrow_wasm PRIVATE /build/arrow/release/libarrow_dataset.a)
target_link_libraries(arrow_wasm PRIVATE /build/arrow/release/libarrow_bundled_dependencies.a)
target_link_libraries(arrow_wasm PRIVATE /openssl/libcrypto.a)
target_link_libraries(arrow_wasm PRIVATE /openssl/libssl.a)
target_link_libraries(arrow_wasm PRIVATE /curl/lib/.libs/libcurl.a)
target_link_libraries(arrow_wasm PRIVATE /zlib/libz.a)

set(ASYNCIFY_CALL_STACK "
'dynCall*',
'emscripten::internal::Invoker*',
'read_remote_parquet*',
'write_remote_parquet*',
'arrow::fs::*::ObjectInputFile*',
'*arrow::fs::*::ObjectOutputStream*',
'arrow::fs::S3FileSystem::OpenInputFile*',
'arrow::fs::S3FileSystem::Impl::OpenInputFile*',
'arrow::fs::S3FileSystem::OpenOutputStream*',
'Aws::S3::S3Client::GetObject*',
'Aws::S3::S3Client::CreateMultipartUpload*',
'Aws::Client::AWSXMLClient::MakeRequest*',
'Aws::Client::AWSClient::AttemptExhaustively*',
'Aws::Client::AWSClient::AttemptOneRequest*',
'Aws::Client::AWSClient::MakeRequestWithUnparsedResponse*',
'Aws::Http::CurlHttpClient::MakeRequest*',
'arrow::io::internal::CloseFromDestructor*',
'parquet::SerializedFile::ParseMetaData*',
'parquet::ParquetFileReader::Contents::Open*',
'parquet::ParquetFileReader::Open*',
'parquet::ReaderProperties::GetStream*',
'parquet::SerializedRowGroup::GetColumnPageReader*',
'parquet::RowGroupReader::GetColumnPageReader*',
'parquet::arrow::FileColumnIterator::NextChunk*',
'parquet::arrow::*::GetReader*',
'parquet::arrow::*::FileReaderImpl::GetFieldReader*',
'parquet::arrow::*::FileReaderImpl::ReadRowGroups*',
'parquet::arrow::*::FileReaderImpl::ReadTable*',
'*arrow::fs::S3FileSystem::Impl::ListObjectsV2*',
'arrow::fs::S3FileSystem::Impl::Walk*',
'arrow::fs::S3FileSystem::GetFileInfo*',
'arrow::dataset::ParquetFileFormat::GetReader*',
'arrow::dataset::ParquetFileFormat::Inspect*',
'arrow::dataset::FileSystemDatasetFactory::Make*',
'arrow::dataset::FileSystemDatasetFactory::InspectSchemas*',
'arrow::dataset::FileSystemDatasetFactory::Finish*',
'arrow::dataset::DatasetFactory::Inspect*',
'arrow::dataset::DatasetFactory::Finish*',
'arrow::dataset::ParquetFileFragment::EnsureCompleteMetadata*',
'arrow::dataset::ParquetFileFragment::ReadPhysicalSchemaImpl*',
'arrow::dataset::Fragment::ReadPhysicalSchema*'
")
string(REGEX REPLACE "\n" "" ASYNCIFY_CALL_STACK "${ASYNCIFY_CALL_STACK}")

set_target_properties(arrow_wasm PROPERTIES LINK_FLAGS "--bind -g -O2 -s ENVIRONMENT='web' -s WASM=1 -s ASYNCIFY=1 -s ASYNCIFY_ADVISE=0 -s ASYNCIFY_IGNORE_INDIRECT=0 -s ASYNCIFY_ADD=\"[${ASYNCIFY_CALL_STACK}]\" -s FETCH=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s ASSERTIONS=1 -s NO_EXIT_RUNTIME=1 -s FORCE_FILESYSTEM=1 -s EXPORT_ES6=1 -s USE_ES6_IMPORT_META=0 -s MODULARIZE=1 -s EXPORT_NAME='Arrow' -s EXPORTED_RUNTIME_METHODS=\"['FS']\"")

