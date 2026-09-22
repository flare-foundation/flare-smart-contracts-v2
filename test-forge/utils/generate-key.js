const elliptic = require("elliptic");
const ec = new elliptic.ec("secp256k1");

// generate a random private key
const keyPair = ec.genKeyPair();
const x = keyPair.getPublic().getX().toBuffer(undefined, 32);
const y = keyPair.getPublic().getY().toBuffer(undefined, 32);

// output x and y as a concatenated hex string
const hexOutput = x.toString("hex") + y.toString("hex");
process.stdout.write(hexOutput);