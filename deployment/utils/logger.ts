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
      winston.format.printf(json => {
        if (json.label) {
          return `${json.timestamp} - ${json.label}:[${json.level}]: ${json.message}`;
        } else {
          return `${json.timestamp} - [${json.level}]: ${json.message}`;
        }
      })
    ),
    level: process.env.LOG_LEVEL || "info",
    transports: transports,
  });

  loggers.set(label, logger);
  return logger;
}
