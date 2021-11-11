# arrow-wasm

Build universal wasm modules that depend on arrow using docker. There are many arrow-wasm flavours around, this one provides csv, parquet, and parquet encryption support.

## Usage

Build the builder
```
docker build . -t arrow
```

Compile a wasm module from the src directory
```
docker run -v $(pwd)/src:/src arrow
```
