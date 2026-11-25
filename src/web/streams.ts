import { isAsyncIterable } from "./iterable.ts";

type Waiter<R> = {
  resolve: (result: ReadableStreamReadResult<R>) => void;
  reject: (reason: unknown) => void;
};

type Source<R> = {
  start?: (controller: StreamController<R>) => unknown;
  pull?: (controller: StreamController<R>) => unknown;
  cancel?: (reason: unknown) => unknown;
};

type StreamController<R> = {
  readonly desiredSize: number | null;
  enqueue: (chunk: R) => void;
  close: () => void;
  error: (reason?: unknown) => void;
};

export class ReadableStreamShim<R = Uint8Array> {
  static from<R>(
    iterable: Iterable<R> | AsyncIterable<R>,
  ): ReadableStreamShim<R> {
    const iterator = isAsyncIterable(iterable)
      ? iterable[Symbol.asyncIterator]()
      : iterable[Symbol.iterator]();
    return new ReadableStreamShim<R>({
      async pull(controller) {
        const result = await iterator.next();
        if (result.done === true) controller.close();
        else controller.enqueue(result.value);
      },
      async cancel(reason) {
        await iterator.return?.(reason);
      },
    });
  }

  #source: Source<R>;
  #queue: Array<R> = [];
  #waiting: Array<Waiter<R>> = [];
  #state: "readable" | "closed" | "errored" = "readable";
  #error: unknown;
  #closeRequested = false;
  #started = false;
  #pulling = false;
  #pullAgain = false;
  #highWaterMark: number;
  #reader: ReadableStreamDefaultReaderShim<R> | null = null;
  #controller: StreamController<R>;
  #disturbed = false;

  constructor(
    source: Source<R> = {},
    strategy: { highWaterMark?: number } = {},
  ) {
    this.#source = source;
    this.#highWaterMark = strategy.highWaterMark ?? 1;
    const desiredSize = (): number | null =>
      this.#state === "errored"
        ? null
        : this.#state === "closed"
          ? 0
          : this.#highWaterMark - this.#queue.length;
    this.#controller = {
      get desiredSize() {
        return desiredSize();
      },
      enqueue: (chunk) => this.#enqueue(chunk),
      close: () => this.#close(),
      error: (reason) => this.#fail(reason),
    };
    void this.#begin(source.start?.(this.#controller));
  }

  #enqueue(chunk: R): void {
    if (this.#closeRequested || this.#state !== "readable")
      throw new TypeError("The stream is closed");
    const waiter = this.#waiting.shift();
    if (waiter != null) waiter.resolve({ done: false, value: chunk });
    else this.#queue.push(chunk);
    this.#pullIfNeeded();
  }

  #close(): void {
    if (this.#closeRequested || this.#state !== "readable")
      throw new TypeError("The stream is closed");
    this.#closeRequested = true;
    if (this.#queue.length === 0) this.#finish();
  }

  #finish(): void {
    this.#state = "closed";
    for (const waiter of this.#waiting.splice(0))
      waiter.resolve({ done: true, value: undefined });
    this.#reader?.settle(null);
  }

  #fail(reason: unknown): void {
    if (this.#state !== "readable") return;
    this.#state = "errored";
    this.#error = reason;
    this.#queue = [];
    for (const waiter of this.#waiting.splice(0)) waiter.reject(reason);
    this.#reader?.settle(reason ?? new TypeError("The stream errored"));
  }

  #pullIfNeeded(): void {
    if (
      !this.#started ||
      this.#closeRequested ||
      this.#state !== "readable" ||
      this.#source.pull == null
    )
      return;
    if (this.#waiting.length === 0 && this.#queue.length >= this.#highWaterMark)
      return;
    if (this.#pulling) {
      this.#pullAgain = true;
      return;
    }
    this.#pulling = true;
    void this.#pull(this.#source.pull(this.#controller));
  }

  async #begin(starting: unknown): Promise<void> {
    try {
      await starting;
    } catch (error) {
      this.#fail(error);
      return;
    }
    this.#started = true;
    this.#pullIfNeeded();
  }

  async #pull(pulling: unknown): Promise<void> {
    try {
      await pulling;
    } catch (error) {
      this.#fail(error);
      return;
    }
    this.#pulling = false;
    if (!this.#pullAgain) return;
    this.#pullAgain = false;
    this.#pullIfNeeded();
  }

  get disturbed(): boolean {
    return this.#disturbed;
  }

  get locked(): boolean {
    return this.#reader != null;
  }

  getReader(): ReadableStreamDefaultReaderShim<R> {
    if (this.#reader != null) throw new TypeError("ReadableStream is locked");
    this.#reader = new ReadableStreamDefaultReaderShim(this);
    return this.#reader;
  }

  async cancel(reason?: unknown): Promise<void> {
    if (this.#reader != null) throw new TypeError("ReadableStream is locked");
    return this.cancelFromReader(reason);
  }

  async cancelFromReader(reason?: unknown): Promise<void> {
    this.#disturbed = true;
    if (this.#state === "closed") return;
    if (this.#state === "errored") throw this.#error;
    this.#queue = [];
    this.#finish();
    await this.#source.cancel?.(reason);
  }

  releaseFromReader(): void {
    this.#reader = null;
  }

  async readFromReader(): Promise<ReadableStreamReadResult<R>> {
    this.#disturbed = true;
    if (this.#queue.length > 0) {
      const value = this.#queue.shift() as R;
      if (this.#closeRequested && this.#queue.length === 0) this.#finish();
      else this.#pullIfNeeded();
      return { done: false, value };
    }
    if (this.#state === "closed") return { done: true, value: undefined };
    if (this.#state === "errored") throw this.#error;
    const { promise, resolve, reject } =
      Promise.withResolvers<ReadableStreamReadResult<R>>();
    this.#waiting.push({ resolve, reject });
    this.#pullIfNeeded();
    return promise;
  }

  async *values({ preventCancel = false } = {}): AsyncGenerator<
    R,
    undefined,
    undefined
  > {
    const reader = this.getReader();
    let isFinished = false;
    try {
      for (;;) {
        const result = await reader.read();
        if (result.done) {
          isFinished = true;
          return undefined;
        }
        yield result.value;
      }
    } finally {
      if (!isFinished && !preventCancel) await reader.cancel();
      reader.releaseLock();
    }
  }

  [Symbol.asyncIterator](): AsyncGenerator<R, undefined, undefined> {
    return this.values();
  }

  tee(): [ReadableStreamShim<R>, ReadableStreamShim<R>] {
    const reader = this.getReader();
    const branches: Array<StreamController<R>> = [];
    let reading: Promise<void> | null = null;
    const deliver = async (): Promise<void> => {
      const result = await reader.read();
      reading = null;
      for (const branch of branches) {
        if (result.done) branch.close();
        else branch.enqueue(result.value);
      }
    };
    const pull = async (): Promise<void> => {
      reading ??= deliver();
      return reading;
    };
    const make = (): ReadableStreamShim<R> =>
      new ReadableStreamShim<R>({
        start: (controller) => void branches.push(controller),
        pull,
      });
    return [make(), make()];
  }
}

export class ReadableStreamDefaultReaderShim<R> {
  #stream: ReadableStreamShim<R> | null;
  #settle: {
    resolve: (value: undefined) => void;
    reject: (reason: unknown) => void;
  };
  readonly closed: Promise<undefined>;

  constructor(stream: ReadableStreamShim<R>) {
    this.#stream = stream;
    const { promise, resolve, reject } = Promise.withResolvers<undefined>();
    void Promise.allSettled([promise]);
    this.closed = promise;
    this.#settle = { resolve, reject };
  }

  settle(error: unknown): void {
    if (error == null) this.#settle.resolve(undefined);
    else this.#settle.reject(error);
  }

  async read(): Promise<ReadableStreamReadResult<R>> {
    if (this.#stream == null) throw new TypeError("The reader was released");
    return this.#stream.readFromReader();
  }

  async cancel(reason?: unknown): Promise<void> {
    if (this.#stream == null) throw new TypeError("The reader was released");
    return this.#stream.cancelFromReader(reason);
  }

  releaseLock(): void {
    this.#stream?.releaseFromReader();
    this.#stream = null;
  }
}

export async function readAll(stream: {
  getReader: () => { read: () => Promise<ReadableStreamReadResult<unknown>> };
}): Promise<Uint8Array<ArrayBuffer>> {
  const reader = stream.getReader();
  const chunks: Array<Uint8Array> = [];
  let length = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!(value instanceof Uint8Array))
      throw new TypeError("The stream chunk is not a Uint8Array");
    chunks.push(value);
    length += value.length;
  }
  const output = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.length;
  }
  return output;
}
