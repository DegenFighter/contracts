const ethers = require('ethers')
const { IProxy } = require('../')

;(async () => {
  const wallet = new ethers.Wallet(
      '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', 
      new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')
    )
    
  const c = new ethers.Contract(
    '0x5FbDB2315678afecb367f032d93F642f64180aa3', 
    IProxy, 
    wallet
  )

  const ret = await c.getTotalBouts()

  console.log(ret)

})().catch(err => {
  console.error(err)
  process.exit(-1)
})
