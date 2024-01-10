export function asError(e: unknown): Error {
  if (e instanceof Error) {
    return e;
  } else {
    throw new Error(`Unknown object thrown as error: ${JSON.stringify(e)}`);
  }
}

/** Returns error message including stack trace and the `cause` error, if defined. */
export function errorString(error: unknown) {
  if (error instanceof Error) {
    const errorDetails = (e: Error) => (e.stack ? `\n${e.stack}` : e.message);
    const cause = error.cause instanceof Error ? `\n[Caused by]: ${errorDetails(error.cause)}` : "";
    return errorDetails(error) + cause;
  } else {
    return `Caught a non-error objet: ${JSON.stringify(error)}`;
  }
}
