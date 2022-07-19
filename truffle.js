module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*",
      gas: 4600000
    },
  },
  compilers: {
    solc: {
      version: "^0.4.26"
    }
  }
};