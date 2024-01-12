/**
 * Simple and efficient implementation of a queue suitable for larger sizes
 */
export class Queue<T> {
  private data: { [key: number]: T } = {};
  private head = 0; // first index
  private tail = 0; // first empty index

  /**
   * Add an @param item to the end of the queue
   */
  public push(item: T): void {
    this.data[this.tail] = item;
    this.tail++;
  }

  /**
   * Add an @param item to the beginning of the queue
   */
  public prepend(item: T): void {
    this.data[this.head - 1] = item;
    this.head--;
  }

  // Can be called only if head < tail
  public shift(): T {
    const item = this.first;
    delete this.data[this.head];
    this.head++;
    return item;
  }

  public get size() {
    return this.tail - this.head;
  }

  /**
   * Return the first element in the queue
   */
  public get first(): T {
    if (this.size > 0) {
      return this.data[this.head];
    }
    throw Error("Empty queue");
  }

  /**
   * Clears the queue
   */
  public destroy() {
    delete this.data;
    this.data = {};
    this.tail = 0;
    this.head = 0;
  }
}
