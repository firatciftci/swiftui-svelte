export class HttpError {
  readonly status: number;
  readonly body: { message: string };

  constructor(status: number, body: { message: string }) {
    this.status = status;
    this.body = body;
  }
}

export class Redirect {
  readonly status: number;
  readonly location: string;

  constructor(status: number, location: string) {
    this.status = status;
    this.location = location;
  }
}

export function error(
  status: number,
  body: string | { message: string },
): never {
  throw new HttpError(
    status,
    typeof body === "string" ? { message: body } : body,
  );
}

export function redirect(status: number, location: string): never {
  throw new Redirect(status, location);
}

export function isHttpError(
  value: unknown,
  status?: number,
): value is HttpError {
  return (
    value instanceof HttpError && (status == null || value.status === status)
  );
}

export function isRedirect(value: unknown): value is Redirect {
  return value instanceof Redirect;
}
