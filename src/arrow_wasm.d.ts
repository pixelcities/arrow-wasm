/// <reference types="emscripten" />

/* tslint:disable */
/* eslint-disable */
export interface ArrowModule extends EmscriptenModule {
  load_csv(csv: string, path: string);
}

export function Arrow(mod?: any): Promise<ArrowModule>;
