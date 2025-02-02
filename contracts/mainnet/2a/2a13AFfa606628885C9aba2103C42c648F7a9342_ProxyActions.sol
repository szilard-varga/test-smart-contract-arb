// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.


interface GemLike {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface ManagerLike {
    function cdpCan(address, uint256, address) external view returns (uint256);
    function ilks(uint256) external view returns (bytes32);
    function owns(uint256) external view returns (address);
    function urns(uint256) external view returns (address);
    function vat() external view returns (address);
    function open(bytes32, address) external returns (uint256);
    function give(uint256, address) external;
    function cdpAllow(uint256, address, uint256) external;
    function urnAllow(address, uint256) external;
    function frob(uint256, int256, int256) external;
    function flux(uint256, address, uint256) external;
    function move(uint256, address, uint256) external;
    function exit(address, uint256, address, uint256) external;
    function quit(uint256, address) external;
    function enter(address, uint256) external;
    function shift(uint256, uint256) external;
}

interface VatLike {
    function can(address, address) external view returns (uint256);
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function zar(address) external view returns (uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function frob(bytes32, address, address, address, int256, int256) external;
    function hope(address) external;
    function move(address, address, uint256) external;
}

interface GemJoinLike {
    function dec() external returns (uint256);
    function gem() external returns (GemLike);
    function join(address, uint256) external payable;
    function exit(address, uint256) external;
}

interface GNTJoinLike {
    function bags(address) external view returns (address);
    function make(address) external returns (address);
}

interface ZarJoinLike {
    function vat() external returns (VatLike);
    function zar() external returns (GemLike);
    function join(address, uint256) external payable;
    function exit(address, uint256) external;
}

interface HopeLike {
    function hope(address) external;
    function nope(address) external;
}

interface EndLike {
    function fix(bytes32) external view returns (uint256);
    function cash(bytes32, uint256) external;
    function free(bytes32) external;
    function pack(uint256) external;
    function skim(bytes32, address) external;
}

interface JugLike {
    function drip(bytes32) external returns (uint256);
}

interface PotLike {
    function pie(address) external view returns (uint256);
    function drip() external returns (uint256);
    function join(uint256) external;
    function exit(uint256) external;
}

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// WARNING: These functions meant to be used as a a library for a DSProxy. Some are unsafe if you call them directly.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

contract Common {
    uint256 constant RAY = 10 ** 27;

    // Internal functions

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    // Public functions

    function zarJoin_join(address apt, address urn, uint256 wad) public {
        // Gets ZAR from the user's wallet
        ZarJoinLike(apt).zar().transferFrom(msg.sender, address(this), wad);
        // Approves adapter to take the ZAR amount
        ZarJoinLike(apt).zar().approve(apt, wad);
        // Joins ZAR into the vat
        ZarJoinLike(apt).join(urn, wad);
    }
}

contract ProxyActions is Common {
    // Internal functions
    function toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint256 wad) internal pure returns (uint256 rad) {
        rad = mul(wad, 10 ** 27);
    }

    function convertTo18(address gemJoin, uint256 amt) internal returns (uint256 wad) {
        // For those collaterals that have less than 18 decimals precision we need to do the conversion before passing to frob function
        // Adapters will automatically handle the difference of precision
        wad = mul(amt, 10 ** (18 - GemJoinLike(gemJoin).dec()));
    }

    function _getDrawDart(address vat, address jug, address urn, bytes32 ilk, uint256 wad)
        internal
        returns (int256 dart)
    {
        // Updates stability fee rate
        uint256 rate = JugLike(jug).drip(ilk);

        // Gets ZAR balance of the urn in the vat
        uint256 zar = VatLike(vat).zar(urn);

        // If there was already enough ZAR in the vat balance, just exits it without adding more debt
        if (zar < mul(wad, RAY)) {
            // Calculates the needed dart so together with the existing ZAR in the vat is enough to exit wad amount of ZAR tokens
            dart = toInt256((mul(wad, RAY) - zar) / rate);
            // This is neeeded due lack of precision. It might need to sum an extra dart wei (for the given ZAR wad amount)
            dart = mul(uint256(dart), rate) < mul(wad, RAY) ? dart + 1 : dart;
        }
    }

    function _getWipeDart(address vat, uint256 zar, address urn, bytes32 ilk) internal view returns (int256 dart) {
        // Gets actual rate from the vat
        (, uint256 rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        // Uses the whole zar balance in the vat to reduce the debt
        dart = toInt256(zar / rate);
        // Checks the calculated dart is not higher than urn.art (total debt), otherwise uses its value
        dart = uint256(dart) <= art ? -dart : -toInt256(art);
    }

    function _getWipeAllWad(address vat, address usr, address urn, bytes32 ilk) internal view returns (uint256 wad) {
        // Gets actual rate from the vat
        (, uint256 rate,,,) = VatLike(vat).ilks(ilk);
        // Gets actual art value of the urn
        (, uint256 art) = VatLike(vat).urns(ilk, urn);
        // Gets actual zar amount in the urn
        uint256 zar = VatLike(vat).zar(usr);

        uint256 rad = mul(art, rate) - zar;
        wad = rad / RAY;

        // If the rad precision has some dust, it will need to request for 1 extra wad wei
        wad = mul(wad, RAY) < rad ? wad + 1 : wad;
    }

    // Public functions

    function transfer(address gem, address dst, uint256 amt) public {
        GemLike(gem).transfer(dst, amt);
    }

    function ethJoin_join(address apt, address urn) public payable {
        // Wraps ETH in WETH
        GemJoinLike(apt).gem().deposit{value: msg.value}();
        // Approves adapter to take the WETH amount
        GemJoinLike(apt).gem().approve(address(apt), msg.value);
        // Joins WETH collateral into the vat
        GemJoinLike(apt).join(urn, msg.value);
    }

    function gemJoin_join(address apt, address urn, uint256 amt, bool transferFrom) public {
        // Only executes for tokens that have approval/transferFrom implementation
        if (transferFrom) {
            // Gets token from the user's wallet
            GemJoinLike(apt).gem().transferFrom(msg.sender, address(this), amt);
            // Approves adapter to take the token amount
            GemJoinLike(apt).gem().approve(apt, amt);
        }
        // Joins token collateral into the vat
        GemJoinLike(apt).join(urn, amt);
    }

    function hope(address obj, address usr) public {
        HopeLike(obj).hope(usr);
    }

    function nope(address obj, address usr) public {
        HopeLike(obj).nope(usr);
    }

    function open(address manager, bytes32 ilk, address usr) public returns (uint256 cdp) {
        cdp = ManagerLike(manager).open(ilk, usr);
    }

    function give(address manager, uint256 cdp, address usr) public {
        ManagerLike(manager).give(cdp, usr);
    }

    function giveToProxy(address proxyRegistry, address manager, uint256 cdp, address dst) public {
        // Gets actual proxy address
        address proxy = ProxyRegistryLike(proxyRegistry).proxies(dst);
        // Checks if the proxy address already existed and dst address is still the owner
        if (proxy == address(0) || ProxyLike(proxy).owner() != dst) {
            uint256 csize;
            assembly {
                csize := extcodesize(dst)
            }
            // We want to avoid creating a proxy for a contract address that might not be able to handle proxies, then losing the CDP
            require(csize == 0, "Dst-is-a-contract");
            // Creates the proxy for the dst address
            proxy = ProxyRegistryLike(proxyRegistry).build(dst);
        }
        // Transfers CDP to the dst proxy
        give(manager, cdp, proxy);
    }

    function cdpAllow(address manager, uint256 cdp, address usr, uint256 ok) public {
        ManagerLike(manager).cdpAllow(cdp, usr, ok);
    }

    function urnAllow(address manager, address usr, uint256 ok) public {
        ManagerLike(manager).urnAllow(usr, ok);
    }

    function flux(address manager, uint256 cdp, address dst, uint256 wad) public {
        ManagerLike(manager).flux(cdp, dst, wad);
    }

    function move(address manager, uint256 cdp, address dst, uint256 rad) public {
        ManagerLike(manager).move(cdp, dst, rad);
    }

    function frob(address manager, uint256 cdp, int256 dink, int256 dart) public {
        ManagerLike(manager).frob(cdp, dink, dart);
    }

    function quit(address manager, uint256 cdp, address dst) public {
        ManagerLike(manager).quit(cdp, dst);
    }

    function enter(address manager, address src, uint256 cdp) public {
        ManagerLike(manager).enter(src, cdp);
    }

    function shift(address manager, uint256 cdpSrc, uint256 cdpOrg) public {
        ManagerLike(manager).shift(cdpSrc, cdpOrg);
    }

    function makeGemBag(address gemJoin) public returns (address bag) {
        bag = GNTJoinLike(gemJoin).make(address(this));
    }

    function lockETH(address manager, address ethJoin, uint256 cdp) public payable {
        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(ethJoin, address(this));
        // Locks WETH amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            toInt256(msg.value),
            0
        );
    }

    function safeLockETH(address manager, address ethJoin, uint256 cdp, address owner) public payable {
        require(ManagerLike(manager).owns(cdp) == owner, "owner-missmatch");
        lockETH(manager, ethJoin, cdp);
    }

    function lockGem(address manager, address gemJoin, uint256 cdp, uint256 amt, bool transferFrom) public {
        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(gemJoin, address(this), amt, transferFrom);
        // Locks token amount into the CDP
        VatLike(ManagerLike(manager).vat()).frob(
            ManagerLike(manager).ilks(cdp),
            ManagerLike(manager).urns(cdp),
            address(this),
            address(this),
            toInt256(convertTo18(gemJoin, amt)),
            0
        );
    }

    function safeLockGem(address manager, address gemJoin, uint256 cdp, uint256 amt, bool transferFrom, address owner)
        public
    {
        require(ManagerLike(manager).owns(cdp) == owner, "owner-missmatch");
        lockGem(manager, gemJoin, cdp, amt, transferFrom);
    }

    function freeETH(address manager, address ethJoin, uint256 cdp, uint256 wad) public {
        // Unlocks WETH amount from the CDP
        frob(manager, cdp, -toInt256(wad), 0);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wad);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wad);
    }

    function freeGem(address manager, address gemJoin, uint256 cdp, uint256 amt) public {
        uint256 wad = convertTo18(gemJoin, amt);
        // Unlocks token amount from the CDP
        frob(manager, cdp, -toInt256(wad), 0);
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wad);
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }

    function exitETH(address manager, address ethJoin, uint256 cdp, uint256 wad) public {
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wad);

        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wad);
    }

    function exitGem(address manager, address gemJoin, uint256 cdp, uint256 amt) public {
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), convertTo18(gemJoin, amt));

        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }

    function draw(address manager, address jug, address zarJoin, uint256 cdp, uint256 wad) public {
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Generates debt in the CDP
        frob(manager, cdp, 0, _getDrawDart(vat, jug, urn, ilk, wad));
        // Moves the ZAR amount (balance in the vat in rad) to proxy's address
        move(manager, cdp, address(this), toRad(wad));
        // Allows adapter to access to proxy's ZAR balance in the vat
        if (VatLike(vat).can(address(this), address(zarJoin)) == 0) {
            VatLike(vat).hope(zarJoin);
        }
        // Exits ZAR to the user's wallet as a token
        ZarJoinLike(zarJoin).exit(msg.sender, wad);
    }

    function wipe(address manager, address zarJoin, uint256 cdp, uint256 wad) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);

        address own = ManagerLike(manager).owns(cdp);
        if (own == address(this) || ManagerLike(manager).cdpCan(own, cdp, address(this)) == 1) {
            // Joins ZAR amount into the vat
            zarJoin_join(zarJoin, urn, wad);
            // Paybacks debt to the CDP
            frob(manager, cdp, 0, _getWipeDart(vat, VatLike(vat).zar(urn), urn, ilk));
        } else {
            // Joins ZAR amount into the vat
            zarJoin_join(zarJoin, address(this), wad);
            // Paybacks debt to the CDP
            VatLike(vat).frob(ilk, urn, address(this), address(this), 0, _getWipeDart(vat, wad * RAY, urn, ilk));
        }
    }

    function safeWipe(address manager, address zarJoin, uint256 cdp, uint256 wad, address owner) public {
        require(ManagerLike(manager).owns(cdp) == owner, "owner-missmatch");
        wipe(manager, zarJoin, cdp, wad);
    }

    function wipeAll(address manager, address zarJoin, uint256 cdp) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        address own = ManagerLike(manager).owns(cdp);
        if (own == address(this) || ManagerLike(manager).cdpCan(own, cdp, address(this)) == 1) {
            // Joins ZAR amount into the vat
            zarJoin_join(zarJoin, urn, _getWipeAllWad(vat, urn, urn, ilk));
            // Paybacks debt to the CDP
            frob(manager, cdp, 0, -int256(art));
        } else {
            // Joins ZAR amount into the vat
            zarJoin_join(zarJoin, address(this), _getWipeAllWad(vat, address(this), urn, ilk));
            // Paybacks debt to the CDP
            VatLike(vat).frob(ilk, urn, address(this), address(this), 0, -int256(art));
        }
    }

    function safeWipeAll(address manager, address zarJoin, uint256 cdp, address owner) public {
        require(ManagerLike(manager).owns(cdp) == owner, "owner-missmatch");
        wipeAll(manager, zarJoin, cdp);
    }

    function lockETHAndDraw(address manager, address jug, address ethJoin, address zarJoin, uint256 cdp, uint256 wadD)
        public
        payable
    {
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Receives ETH amount, converts it to WETH and joins it into the vat
        ethJoin_join(ethJoin, urn);
        // Locks WETH amount into the CDP and generates debt
        frob(manager, cdp, toInt256(msg.value), _getDrawDart(vat, jug, urn, ilk, wadD));
        // Moves the ZAR amount (balance in the vat in rad) to proxy's address
        move(manager, cdp, address(this), toRad(wadD));
        // Allows adapter to access to proxy's ZAR balance in the vat
        if (VatLike(vat).can(address(this), address(zarJoin)) == 0) {
            VatLike(vat).hope(zarJoin);
        }
        // Exits ZAR to the user's wallet as a token
        ZarJoinLike(zarJoin).exit(msg.sender, wadD);
    }

    function openLockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address zarJoin,
        bytes32 ilk,
        uint256 wadD
    ) public payable returns (uint256 cdp) {
        cdp = open(manager, ilk, address(this));
        lockETHAndDraw(manager, jug, ethJoin, zarJoin, cdp, wadD);
    }

    function lockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address zarJoin,
        uint256 cdp,
        uint256 amtC,
        uint256 wadD,
        bool transferFrom
    ) public {
        address urn = ManagerLike(manager).urns(cdp);
        address vat = ManagerLike(manager).vat();
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        // Takes token amount from user's wallet and joins into the vat
        gemJoin_join(gemJoin, urn, amtC, transferFrom);
        // Locks token amount into the CDP and generates debt
        frob(manager, cdp, toInt256(convertTo18(gemJoin, amtC)), _getDrawDart(vat, jug, urn, ilk, wadD));
        // Moves the ZAR amount (balance in the vat in rad) to proxy's address
        move(manager, cdp, address(this), toRad(wadD));
        // Allows adapter to access to proxy's ZAR balance in the vat
        if (VatLike(vat).can(address(this), address(zarJoin)) == 0) {
            VatLike(vat).hope(zarJoin);
        }
        // Exits ZAR to the user's wallet as a token
        ZarJoinLike(zarJoin).exit(msg.sender, wadD);
    }

    function openLockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address zarJoin,
        bytes32 ilk,
        uint256 amtC,
        uint256 wadD,
        bool transferFrom
    ) public returns (uint256 cdp) {
        cdp = open(manager, ilk, address(this));
        lockGemAndDraw(manager, jug, gemJoin, zarJoin, cdp, amtC, wadD, transferFrom);
    }

    function openLockGNTAndDraw(
        address manager,
        address jug,
        address gntJoin,
        address zarJoin,
        bytes32 ilk,
        uint256 amtC,
        uint256 wadD
    ) public returns (address bag, uint256 cdp) {
        // Creates bag (if doesn't exist) to hold GNT
        bag = GNTJoinLike(gntJoin).bags(address(this));
        if (bag == address(0)) {
            bag = makeGemBag(gntJoin);
        }
        // Transfer funds to the funds which previously were sent to the proxy
        GemLike(GemJoinLike(gntJoin).gem()).transfer(bag, amtC);
        cdp = openLockGemAndDraw(manager, jug, gntJoin, zarJoin, ilk, amtC, wadD, false);
    }

    function wipeAndFreeETH(address manager, address ethJoin, address zarJoin, uint256 cdp, uint256 wadC, uint256 wadD)
        public
    {
        address urn = ManagerLike(manager).urns(cdp);
        // Joins zar amount into the vat
        zarJoin_join(zarJoin, urn, wadD);
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(
            manager,
            cdp,
            -toInt256(wadC),
            _getWipeDart(
                ManagerLike(manager).vat(),
                VatLike(ManagerLike(manager).vat()).zar(urn),
                urn,
                ManagerLike(manager).ilks(cdp)
            )
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wadC);
    }

    function wipeAllAndFreeETH(address manager, address ethJoin, address zarJoin, uint256 cdp, uint256 wadC) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        // Joins ZAR amount into the vat
        zarJoin_join(zarJoin, urn, _getWipeAllWad(vat, urn, urn, ilk));
        // Paybacks debt to the CDP and unlocks WETH amount from it
        frob(manager, cdp, -toInt256(wadC), -int256(art));
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wadC);
    }

    function wipeAndFreeGem(address manager, address gemJoin, address zarJoin, uint256 cdp, uint256 amtC, uint256 wadD)
        public
    {
        address urn = ManagerLike(manager).urns(cdp);
        // Joins ZAR amount into the vat
        zarJoin_join(zarJoin, urn, wadD);
        uint256 wadC = convertTo18(gemJoin, amtC);
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(
            manager,
            cdp,
            -toInt256(wadC),
            _getWipeDart(
                ManagerLike(manager).vat(),
                VatLike(ManagerLike(manager).vat()).zar(urn),
                urn,
                ManagerLike(manager).ilks(cdp)
            )
        );
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amtC);
    }

    function wipeAllAndFreeGem(address manager, address gemJoin, address zarJoin, uint256 cdp, uint256 amtC) public {
        address vat = ManagerLike(manager).vat();
        address urn = ManagerLike(manager).urns(cdp);
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        (, uint256 art) = VatLike(vat).urns(ilk, urn);

        // Joins ZAR amount into the vat
        zarJoin_join(zarJoin, urn, _getWipeAllWad(vat, urn, urn, ilk));
        uint256 wadC = convertTo18(gemJoin, amtC);
        // Paybacks debt to the CDP and unlocks token amount from it
        frob(manager, cdp, -toInt256(wadC), -int256(art));
        // Moves the amount from the CDP urn to proxy's address
        flux(manager, cdp, address(this), wadC);
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amtC);
    }
}

contract ProxyActionsEnd is Common {
    // Internal functions

    function _free(address manager, address end, uint256 cdp) internal returns (uint256 ink) {
        bytes32 ilk = ManagerLike(manager).ilks(cdp);
        address urn = ManagerLike(manager).urns(cdp);
        VatLike vat = VatLike(ManagerLike(manager).vat());
        uint256 art;
        (ink, art) = vat.urns(ilk, urn);

        // If CDP still has debt, it needs to be paid
        if (art > 0) {
            EndLike(end).skim(ilk, urn);
            (ink,) = vat.urns(ilk, urn);
        }
        // Approves the manager to transfer the position to proxy's address in the vat
        if (vat.can(address(this), address(manager)) == 0) {
            vat.hope(manager);
        }
        // Transfers position from CDP to the proxy address
        ManagerLike(manager).quit(cdp, address(this));
        // Frees the position and recovers the collateral in the vat registry
        EndLike(end).free(ilk);
    }

    // Public functions
    function freeETH(address manager, address ethJoin, address end, uint256 cdp) public {
        uint256 wad = _free(manager, end, cdp);
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wad);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wad);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wad);
    }

    function freeGem(address manager, address gemJoin, address end, uint256 cdp) public {
        uint256 amt = _free(manager, end, cdp) / 10 ** (18 - GemJoinLike(gemJoin).dec());
        // Exits token amount to the user's wallet as a token
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }

    function pack(address zarJoin, address end, uint256 wad) public {
        zarJoin_join(zarJoin, address(this), wad);
        VatLike vat = ZarJoinLike(zarJoin).vat();
        // Approves the end to take out ZAR from the proxy's balance in the vat
        if (vat.can(address(this), address(end)) == 0) {
            vat.hope(end);
        }
        EndLike(end).pack(wad);
    }

    function cashETH(address ethJoin, address end, bytes32 ilk, uint256 wad) public {
        EndLike(end).cash(ilk, wad);
        uint256 wadC = mul(wad, EndLike(end).fix(ilk)) / RAY;
        // Exits WETH amount to proxy address as a token
        GemJoinLike(ethJoin).exit(address(this), wadC);
        // Converts WETH to ETH
        GemJoinLike(ethJoin).gem().withdraw(wadC);
        // Sends ETH back to the user's wallet
        payable(msg.sender).transfer(wadC);
    }

    function cashGem(address gemJoin, address end, bytes32 ilk, uint256 wad) public {
        EndLike(end).cash(ilk, wad);
        // Exits token amount to the user's wallet as a token
        uint256 amt = mul(wad, EndLike(end).fix(ilk)) / RAY / 10 ** (18 - GemJoinLike(gemJoin).dec());
        GemJoinLike(gemJoin).exit(msg.sender, amt);
    }
}