// SPDX-License-Identifier: MIT
// pragma solidity >=0.8.17 <0.9;
pragma solidity >=0.8.13;

import "forge-std/StdJson.sol";
import "solidity-stringutils/strings.sol";
import "forge-std/Script.sol";

// import { DEPLOYER_SYSTEM_CONTRACT } from "lib/v2-testnet-contracts/l2/system-contracts/Constants.sol";
import "lib/v2-testnet-contracts/l2/system-contracts/interfaces/IContractDeployer.sol";
uint160 constant SYSTEM_CONTRACTS_OFFSET = 0x8000; // 2^15

IContractDeployer constant DEPLOYER_SYSTEM_CONTRACT = IContractDeployer(
    address(SYSTEM_CONTRACTS_OFFSET + 0x06)
);

///@notice This cheat codes interface is named _CheatCodes so you can use the CheatCodes interface in other testing files without errors
interface _CheatCodes {
    function ffi(string[] calldata) external returns (bytes memory);

    function envString(string calldata key) external returns (string memory value);

    function parseJson(
        string memory json,
        string memory key
    ) external returns (string memory value);

    function writeFile(string calldata, string calldata) external;

    function readFile(string calldata) external returns (string memory);
}

contract Deployer {
    using stdJson for string;
    using strings for *;

    address constant HEVM_ADDRESS =
        address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

    _CheatCodes cheatCodes = _CheatCodes(HEVM_ADDRESS);

    function compileContract(string memory fileName) public returns (bytes memory) {
        ///@notice Grabs the path of the config file for zksolc from env.
        ///@notice If none is found, default to the one defined in this project
        string memory configFile;
        try cheatCodes.envString("CONFIG_FILE") returns (string memory value) {
            configFile = value;
        } catch {
            configFile = "zksolc.json";
        }

        ///@notice Parses config values from file
        // string memory config = cheatCodes.readFile(configFile);
        // string memory os = config.readString("os");
        // string memory arch = config.readString("arch");
        // string memory version = config.readString("version");

        ///@notice Constructs zksolc path from config
        // string memory zksolcPath = string(
        //     abi.encodePacked(
        //         "lib/zksolc-bin/",
        //         os,
        //         "-",
        //         arch,
        //         "/zksolc-",
        //         os,
        //         "-",
        //         arch,
        //         "-v",
        //         version
        //     )
        // );
        string memory zksolcPath = string(
            abi.encodePacked(
                "lib/zksolc-bin/",
                "macosx",
                "-",
                "amd64",
                "/zksolc-",
                "macosx",
                "-",
                "amd64",
                "-v",
                "1.3.1"
            )
        );
        ///@notice Compiles the contract using zksolc
        string[] memory cmds = new string[](3);
        cmds[0] = zksolcPath;
        cmds[1] = "--bin";
        cmds[2] = fileName;
        bytes memory output = cheatCodes.ffi(cmds);

        ///@notice Parses bytecode from zksolc output
        strings.slice memory result = string(output).toSlice();
        return bytes(result.rsplit(" ".toSlice()).toString());
    }

    function deployContract(string memory fileName) public returns (address) {
        bytes memory bytecode = compileContract(fileName);

        ///@notice deploy the bytecode with the create instruction
        address deployedAddress;

        assembly {
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        ///@notice check that the deployment was successful
        require(deployedAddress != address(0), "Deployer could not deploy contract");
    }
}

contract DeployToZksync is Script {
    Deployer public deployer;

    function setUp() public {
        deployer = new Deployer();
    }

    function run() public {
        bytes memory bytecode = deployer.compileContract("src/Counter.sol");

        bytes32 salt;
        bytes32 bytecodeHash = 0x00011A4278d12e92e94f989931c919eef1fc704ff6b8ae33ec251e5a20c387a4;

        // first two bytes - version of bytecode hash

        // second two bytes - length of bytecode
        console2.log("bytecode length: ", bytecode.length);
        sha256(bytecode);
        vm.broadcast();
        address newAddress = DEPLOYER_SYSTEM_CONTRACT.create(salt, bytecodeHash, bytecode);
        // deployer.deployContract("src/Proxy.sol");
        // deployer.deployContract("src/facets/BettingFacet.sol");
        // deployer.deployContract("src/MemeToken.sol");
        // deployer.deployContract("src/Counter.sol");
    }
}
// deleted "first" 8 bytes
// 78d12e92e94f989931c919eef1fc704ff6b8ae33ec251e5a20c387a4

// b48d6cf378d12e92e94f989931c919eef1fc704ff6b8ae33ec251e5a

// construct bytecode hash
// 1A42
// 0x00011A42b48d6cf378d12e92e94f989931c919eef1fc704ff6b8ae33ec251e5a
