import winston, { Logger } from "winston";
import TransportStream from "winston-transport";

const logPath = process.env.LOG_PATH ? process.env.LOG_PATH + "/" : "./logs/";
let globalTransport: TransportStream;

/**
 * Configures all newly created loggers to write to the specified file.
 * Note: existing logger instances will not be affected.
 */
export function setGlobalLogFile(filename: string) {
  if (globalTransport) {
    throw Error("Global log file already configured.");
  }
  globalTransport = new winston.transports.File({ filename: `${logPath}${filename}.log` });
}

const loggers = new Map<string, Logger>();

export function getLogger(label: string): Logger {
  if (loggers.has(label)) return loggers.get(label)!;

  const transports: TransportStream[] = [new winston.transports.Console()];
  if (globalTransport) {
    transports.push(globalTransport);
  }

  const logger = winston.createLogger({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.timestamp(),
      winston.format.json(),
      winston.format.label({
        label: label,
      }),
      winston.format.printf((info) => {
        if (info.label) {
          return `${String(info.timestamp)} - ${info.label as string}:[${info.level}]: ${String(info.message)}`;
        } else {
          return `${String(info.timestamp)} - [${info.level}]: ${String(info.message)}`;
        }
      })
    ),
    level: process.env.LOG_LEVEL || "info",
    transports: transports,
  });

  loggers.set(label, logger);
  return logger;
}
