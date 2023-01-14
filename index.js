const { abi: Proxy } = require('./out/IProxy.sol/IProxy.json')
const { abi: IERC20 } = require('./out/IERC20.sol/IERC20.json')
const { abi: IERC173 } = require('./out/IERC20.sol/IERC173.json')

exports.abi = {
  Proxy, IERC20, IERC173
}