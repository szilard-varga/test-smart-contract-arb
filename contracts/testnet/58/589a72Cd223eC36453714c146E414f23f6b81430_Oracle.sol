// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.3) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. It the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`.
        // We also know that `k`, the position of the most significant bit, is such that `msb(a) = 2**k`.
        // This gives `2**k < a <= 2**(k+1)` → `2**(k/2) <= sqrt(a) < 2 ** (k/2+1)`.
        // Using an algorithm similar to the msb conmputation, we are able to compute `result = 2**(k/2)` which is a
        // good first aproximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1;
        uint256 x = a;
        if (x >> 128 > 0) {
            x >>= 128;
            result <<= 64;
        }
        if (x >> 64 > 0) {
            x >>= 64;
            result <<= 32;
        }
        if (x >> 32 > 0) {
            x >>= 32;
            result <<= 16;
        }
        if (x >> 16 > 0) {
            x >>= 16;
            result <<= 8;
        }
        if (x >> 8 > 0) {
            x >>= 8;
            result <<= 4;
        }
        if (x >> 4 > 0) {
            x >>= 4;
            result <<= 2;
        }
        if (x >> 2 > 0) {
            result <<= 1;
        }

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        uint256 result = sqrt(a);
        if (rounding == Rounding.Up && result * result < a) {
            result += 1;
        }
        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/SafeCast.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248) {
        require(value >= type(int248).min && value <= type(int248).max, "SafeCast: value doesn't fit in 248 bits");
        return int248(value);
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240) {
        require(value >= type(int240).min && value <= type(int240).max, "SafeCast: value doesn't fit in 240 bits");
        return int240(value);
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232) {
        require(value >= type(int232).min && value <= type(int232).max, "SafeCast: value doesn't fit in 232 bits");
        return int232(value);
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224) {
        require(value >= type(int224).min && value <= type(int224).max, "SafeCast: value doesn't fit in 224 bits");
        return int224(value);
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216) {
        require(value >= type(int216).min && value <= type(int216).max, "SafeCast: value doesn't fit in 216 bits");
        return int216(value);
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208) {
        require(value >= type(int208).min && value <= type(int208).max, "SafeCast: value doesn't fit in 208 bits");
        return int208(value);
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200) {
        require(value >= type(int200).min && value <= type(int200).max, "SafeCast: value doesn't fit in 200 bits");
        return int200(value);
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192) {
        require(value >= type(int192).min && value <= type(int192).max, "SafeCast: value doesn't fit in 192 bits");
        return int192(value);
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184) {
        require(value >= type(int184).min && value <= type(int184).max, "SafeCast: value doesn't fit in 184 bits");
        return int184(value);
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176) {
        require(value >= type(int176).min && value <= type(int176).max, "SafeCast: value doesn't fit in 176 bits");
        return int176(value);
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168) {
        require(value >= type(int168).min && value <= type(int168).max, "SafeCast: value doesn't fit in 168 bits");
        return int168(value);
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160) {
        require(value >= type(int160).min && value <= type(int160).max, "SafeCast: value doesn't fit in 160 bits");
        return int160(value);
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152) {
        require(value >= type(int152).min && value <= type(int152).max, "SafeCast: value doesn't fit in 152 bits");
        return int152(value);
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144) {
        require(value >= type(int144).min && value <= type(int144).max, "SafeCast: value doesn't fit in 144 bits");
        return int144(value);
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136) {
        require(value >= type(int136).min && value <= type(int136).max, "SafeCast: value doesn't fit in 136 bits");
        return int136(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120) {
        require(value >= type(int120).min && value <= type(int120).max, "SafeCast: value doesn't fit in 120 bits");
        return int120(value);
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112) {
        require(value >= type(int112).min && value <= type(int112).max, "SafeCast: value doesn't fit in 112 bits");
        return int112(value);
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104) {
        require(value >= type(int104).min && value <= type(int104).max, "SafeCast: value doesn't fit in 104 bits");
        return int104(value);
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96) {
        require(value >= type(int96).min && value <= type(int96).max, "SafeCast: value doesn't fit in 96 bits");
        return int96(value);
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88) {
        require(value >= type(int88).min && value <= type(int88).max, "SafeCast: value doesn't fit in 88 bits");
        return int88(value);
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80) {
        require(value >= type(int80).min && value <= type(int80).max, "SafeCast: value doesn't fit in 80 bits");
        return int80(value);
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72) {
        require(value >= type(int72).min && value <= type(int72).max, "SafeCast: value doesn't fit in 72 bits");
        return int72(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56) {
        require(value >= type(int56).min && value <= type(int56).max, "SafeCast: value doesn't fit in 56 bits");
        return int56(value);
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48) {
        require(value >= type(int48).min && value <= type(int48).max, "SafeCast: value doesn't fit in 48 bits");
        return int48(value);
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40) {
        require(value >= type(int40).min && value <= type(int40).max, "SafeCast: value doesn't fit in 40 bits");
        return int40(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24) {
        require(value >= type(int24).min && value <= type(int24).max, "SafeCast: value doesn't fit in 24 bits");
        return int24(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// @title ArbSys
// @dev Globally available variables for Arbitrum may have both an L1 and an L2
// value, the ArbSys interface is used to retrieve the L2 value
interface ArbSys {
    function arbBlockNumber() external view returns (uint256);
    function arbBlockHash(uint256 blockNumber) external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./ArbSys.sol";

// @title Chain
// @dev Wrap the calls to retrieve chain variables to handle differences
// between chain implementations
library Chain {
    // if the ARBITRUM_CHAIN_ID changes, a new version of this library
    // and contracts depending on it would need to be deployed
    uint256 constant public ARBITRUM_CHAIN_ID = 42161;
    uint256 constant public ARBITRUM_GOERLI_CHAIN_ID = 421613;

    ArbSys constant public arbSys = ArbSys(address(100));

    // @dev return the current block's timestamp
    // @return the current block's timestamp
    function currentTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    // @dev return the current block's number
    // @return the current block's number
    function currentBlockNumber() internal view returns (uint256) {
        if (shouldUseArbSysValues()) {
            return arbSys.arbBlockNumber();
        }

        return block.number;
    }

    // @dev return the current block's hash
    // @return the current block's hash
    function getBlockHash(uint256 blockNumber) internal view returns (bytes32) {
        if (shouldUseArbSysValues()) {
            return arbSys.arbBlockHash(blockNumber);
        }

        return blockhash(blockNumber);
    }

    function shouldUseArbSysValues() internal view returns (bool) {
        return block.chainid == ARBITRUM_CHAIN_ID || block.chainid == ARBITRUM_GOERLI_CHAIN_ID;

    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../role/RoleModule.sol";
import "../utils/Calc.sol";
import "../utils/Printer.sol";

// @title DataStore
// @dev DataStore for all general state values
contract DataStore is RoleModule {
    using SafeCast for int256;

    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableValues for EnumerableSet.Bytes32Set;
    using EnumerableValues for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.UintSet;

    // store for uint values
    mapping(bytes32 => uint256) public uintValues;
    // store for int values
    mapping(bytes32 => int256) public intValues;
    // store for address values
    mapping(bytes32 => address) public addressValues;
    // store for bool values
    mapping(bytes32 => bool) public boolValues;
    // store for string values
    mapping(bytes32 => string) public stringValues;
    // store for bytes32 values
    mapping(bytes32 => bytes32) public bytes32Values;

    // store for uint[] values
    mapping(bytes32 => uint256[]) public uintArrayValues;
    // store for int[] values
    mapping(bytes32 => int256[]) public intArrayValues;
    // store for address[] values
    mapping(bytes32 => address[]) public addressArrayValues;
    // store for bool[] values
    mapping(bytes32 => bool[]) public boolArrayValues;
    // store for string[] values
    mapping(bytes32 => string[]) public stringArrayValues;
    // store for bytes32[] values
    mapping(bytes32 => bytes32[]) public bytes32ArrayValues;

    // store for bytes32 sets
    mapping(bytes32 => EnumerableSet.Bytes32Set) internal bytes32Sets;
    // store for address sets
    mapping(bytes32 => EnumerableSet.AddressSet) internal addressSets;
    // store for uint256 sets
    mapping(bytes32 => EnumerableSet.UintSet) internal uintSets;

    constructor(RoleStore _roleStore) RoleModule(_roleStore) {}

    // @dev get the uint value for the given key
    // @param key the key of the value
    // @return the uint value for the key
    function getUint(bytes32 key) external view returns (uint256) {
        return uintValues[key];
    }

    // @dev set the uint value for the given key
    // @param key the key of the value
    // @param value the value to set
    // @return the uint value for the key
    function setUint(bytes32 key, uint256 value) external onlyController returns (uint256) {
        uintValues[key] = value;
        return value;
    }

    // @dev delete the uint value for the given key
    // @param key the key of the value
    function removeUint(bytes32 key) external onlyController {
        delete uintValues[key];
    }

    // @dev add the input int value to the existing uint value
    // @param key the key of the value
    // @param value the input int value
    // @return the new uint value
    function applyDeltaToUint(bytes32 key, int256 value, string memory errorMessage) external onlyController returns (uint256) {
        uint256 currValue = uintValues[key];
        if (value < 0 && (-value).toUint256() > currValue) {
            revert(errorMessage);
        }
        uint256 nextUint = Calc.sumReturnUint256(currValue, value);
        uintValues[key] = nextUint;
        return nextUint;
    }

    // @dev add the input uint value to the existing uint value
    // @param key the key of the value
    // @param value the input int value
    // @return the new uint value
    function applyDeltaToUint(bytes32 key, uint256 value) external onlyController returns (uint256) {
        uint256 currValue = uintValues[key];
        uint256 nextUint = currValue + value;
        uintValues[key] = nextUint;
        return nextUint;
    }

    // @dev add the input int value to the existing uint value, prevent the uint
    // value from becoming negative
    // @param key the key of the value
    // @param value the input int value
    // @return the new uint value
    function applyBoundedDeltaToUint(bytes32 key, int256 value) external onlyController returns (uint256) {
        uint256 uintValue = uintValues[key];
        if (value < 0 && (-value).toUint256() > uintValue) {
            uintValues[key] = 0;
            return 0;
        }

        uint256 nextUint = Calc.sumReturnUint256(uintValue, value);
        uintValues[key] = nextUint;
        return nextUint;
    }

    // @dev add the input uint value to the existing uint value
    // @param key the key of the value
    // @param value the input uint value
    // @return the new uint value
    function incrementUint(bytes32 key, uint256 value) external onlyController returns (uint256) {
        uint256 nextUint = uintValues[key] + value;
        uintValues[key] = nextUint;
        return nextUint;
    }

    // @dev subtract the input uint value from the existing uint value
    // @param key the key of the value
    // @param value the input uint value
    // @return the new uint value
    function decrementUint(bytes32 key, uint256 value) external onlyController returns (uint256) {
        uint256 nextUint = uintValues[key] - value;
        uintValues[key] = nextUint;
        return nextUint;
    }

    // @dev get the int value for the given key
    // @param key the key of the value
    // @return the int value for the key
    function getInt(bytes32 key) external view returns (int256) {
        return intValues[key];
    }

    // @dev set the int value for the given key
    // @param key the key of the value
    // @param value the value to set
    // @return the int value for the key
    function setInt(bytes32 key, int256 value) external onlyController returns (int256) {
        intValues[key] = value;
        return value;
    }

    function removeInt(bytes32 key) external onlyController {
        delete intValues[key];
    }

    // @dev add the input int value to the existing int value
    // @param key the key of the value
    // @param value the input int value
    // @return the new int value
    function applyDeltaToInt(bytes32 key, int256 value) external onlyController returns (int256) {
        int256 nextInt = intValues[key] + value;
        intValues[key] = nextInt;
        return nextInt;
    }

    // @dev add the input int value to the existing int value
    // @param key the key of the value
    // @param value the input int value
    // @return the new int value
    function incrementInt(bytes32 key, int256 value) external onlyController returns (int256) {
        int256 nextInt = intValues[key] + value;
        intValues[key] = nextInt;
        return nextInt;
    }

    // @dev subtract the input int value from the existing int value
    // @param key the key of the value
    // @param value the input int value
    // @return the new int value
    function decrementInt(bytes32 key, int256 value) external onlyController returns (int256) {
        int256 nextInt = intValues[key] - value;
        intValues[key] = nextInt;
        return nextInt;
    }

    // @dev get the address value for the given key
    // @param key the key of the value
    // @return the address value for the key
    function getAddress(bytes32 key) external view returns (address) {
        return addressValues[key];
    }

    // @dev set the address value for the given key
    // @param key the key of the value
    // @param value the value to set
    // @return the address value for the key
    function setAddress(bytes32 key, address value) external onlyController returns (address) {
        addressValues[key] = value;
        return value;
    }

    // @dev delete the address value for the given key
    // @param key the key of the value
    function removeAddress(bytes32 key) external onlyController {
        delete addressValues[key];
    }

    // @dev get the bool value for the given key
    // @param key the key of the value
    // @return the bool value for the key
    function getBool(bytes32 key) external view returns (bool) {
        return boolValues[key];
    }

    // @dev set the bool value for the given key
    // @param key the key of the value
    // @param value the value to set
    // @return the bool value for the key
    function setBool(bytes32 key, bool value) external onlyController returns (bool) {
        boolValues[key] = value;
        return value;
    }

    // @dev delete the bool value for the given key
    // @param key the key of the value
    function removeBool(bytes32 key) external onlyController {
        delete boolValues[key];
    }

    // @dev get the string value for the given key
    // @param key the key of the value
    // @return the string value for the key
    function getString(bytes32 key) external view returns (string memory) {
        return stringValues[key];
    }

    // @dev set the string value for the given key
    // @param key the key of the value
    // @param value the value to set
    // @return the string value for the key
    function setString(bytes32 key, string memory value) external onlyController returns (string memory) {
        stringValues[key] = value;
        return value;
    }

    // @dev delete the string value for the given key
    // @param key the key of the value
    function removeString(bytes32 key) external onlyController {
        delete stringValues[key];
    }

    // @dev get the bytes32 value for the given key
    // @param key the key of the value
    // @return the bytes32 value for the key
    function getBytes32(bytes32 key) external view returns (bytes32) {
        return bytes32Values[key];
    }

    // @dev set the bytes32 value for the given key
    // @param key the key of the value
    // @param value the value to set
    // @return the bytes32 value for the key
    function setBytes32(bytes32 key, bytes32 value) external onlyController returns (bytes32) {
        bytes32Values[key] = value;
        return value;
    }

    // @dev delete the bytes32 value for the given key
    // @param key the key of the value
    function removeBytes32(bytes32 key) external onlyController {
        delete bytes32Values[key];
    }

    // @dev get the uint array for the given key
    // @param key the key of the uint array
    // @return the uint array for the key
    function getUintArray(bytes32 key) external view returns (uint256[] memory) {
        return uintArrayValues[key];
    }

    // @dev set the uint array for the given key
    // @param key the key of the uint array
    // @param value the value of the uint array
    function setUintArray(bytes32 key, uint256[] memory value) external onlyController {
        uintArrayValues[key] = value;
    }

    // @dev delete the uint array for the given key
    // @param key the key of the uint array
    // @param value the value of the uint array
    function removeUintArray(bytes32 key) external onlyController {
        delete uintArrayValues[key];
    }

    // @dev get the int array for the given key
    // @param key the key of the int array
    // @return the int array for the key
    function getIntArray(bytes32 key) external view returns (int256[] memory) {
        return intArrayValues[key];
    }

    // @dev set the int array for the given key
    // @param key the key of the int array
    // @param value the value of the int array
    function setIntArray(bytes32 key, int256[] memory value) external onlyController {
        intArrayValues[key] = value;
    }

    // @dev delete the int array for the given key
    // @param key the key of the int array
    // @param value the value of the int array
    function removeIntArray(bytes32 key) external onlyController {
        delete intArrayValues[key];
    }

    // @dev get the address array for the given key
    // @param key the key of the address array
    // @return the address array for the key
    function getAddressArray(bytes32 key) external view returns (address[] memory) {
        return addressArrayValues[key];
    }

    // @dev set the address array for the given key
    // @param key the key of the address array
    // @param value the value of the address array
    function setAddressArray(bytes32 key, address[] memory value) external onlyController {
        addressArrayValues[key] = value;
    }

    // @dev delete the address array for the given key
    // @param key the key of the address array
    // @param value the value of the address array
    function removeAddressArray(bytes32 key) external onlyController {
        delete addressArrayValues[key];
    }

    // @dev get the bool array for the given key
    // @param key the key of the bool array
    // @return the bool array for the key
    function getBoolArray(bytes32 key) external view returns (bool[] memory) {
        return boolArrayValues[key];
    }

    // @dev set the bool array for the given key
    // @param key the key of the bool array
    // @param value the value of the bool array
    function setBoolArray(bytes32 key, bool[] memory value) external onlyController {
        boolArrayValues[key] = value;
    }

    // @dev delete the bool array for the given key
    // @param key the key of the bool array
    // @param value the value of the bool array
    function removeBoolArray(bytes32 key) external onlyController {
        delete boolArrayValues[key];
    }

    // @dev get the string array for the given key
    // @param key the key of the string array
    // @return the string array for the key
    function getStringArray(bytes32 key) external view returns (string[] memory) {
        return stringArrayValues[key];
    }

    // @dev set the string array for the given key
    // @param key the key of the string array
    // @param value the value of the string array
    function setStringArray(bytes32 key, string[] memory value) external onlyController {
        stringArrayValues[key] = value;
    }

    // @dev delete the string array for the given key
    // @param key the key of the string array
    // @param value the value of the string array
    function removeStringArray(bytes32 key) external onlyController {
        delete stringArrayValues[key];
    }

    // @dev get the bytes32 array for the given key
    // @param key the key of the bytes32 array
    // @return the bytes32 array for the key
    function getBytes32Array(bytes32 key) external view returns (bytes32[] memory) {
        return bytes32ArrayValues[key];
    }

    // @dev set the bytes32 array for the given key
    // @param key the key of the bytes32 array
    // @param value the value of the bytes32 array
    function setBytes32Array(bytes32 key, bytes32[] memory value) external onlyController {
        bytes32ArrayValues[key] = value;
    }

    // @dev delete the bytes32 array for the given key
    // @param key the key of the bytes32 array
    // @param value the value of the bytes32 array
    function removeBytes32Array(bytes32 key) external onlyController {
        delete bytes32ArrayValues[key];
    }

    // @dev check whether the given value exists in the set
    // @param setKey the key of the set
    // @param value the value to check
    function containsBytes32(bytes32 setKey, bytes32 value) external view returns (bool) {
        return bytes32Sets[setKey].contains(value);
    }

    // @dev get the length of the set
    // @param setKey the key of the set
    function getBytes32Count(bytes32 setKey) external view returns (uint256) {
        return bytes32Sets[setKey].length();
    }

    // @dev get the values of the set in the given range
    // @param setKey the key of the set
    // @param the start of the range, values at the start index will be returned
    // in the result
    // @param the end of the range, values at the end index will not be returned
    // in the result
    function getBytes32ValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (bytes32[] memory) {
        return bytes32Sets[setKey].valuesAt(start, end);
    }

    // @dev add the given value to the set
    // @param setKey the key of the set
    // @param value the value to add
    function addBytes32(bytes32 setKey, bytes32 value) external onlyController {
        bytes32Sets[setKey].add(value);
    }

    // @dev remove the given value from the set
    // @param setKey the key of the set
    // @param value the value to remove
    function removeBytes32(bytes32 setKey, bytes32 value) external onlyController {
        bytes32Sets[setKey].remove(value);
    }

    // @dev check whether the given value exists in the set
    // @param setKey the key of the set
    // @param value the value to check
    function containsAddress(bytes32 setKey, address value) external view returns (bool) {
        return addressSets[setKey].contains(value);
    }

    // @dev get the length of the set
    // @param setKey the key of the set
    function getAddressCount(bytes32 setKey) external view returns (uint256) {
        return addressSets[setKey].length();
    }

    // @dev get the values of the set in the given range
    // @param setKey the key of the set
    // @param the start of the range, values at the start index will be returned
    // in the result
    // @param the end of the range, values at the end index will not be returned
    // in the result
    function getAddressValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (address[] memory) {
        return addressSets[setKey].valuesAt(start, end);
    }

    // @dev add the given value to the set
    // @param setKey the key of the set
    // @param value the value to add
    function addAddress(bytes32 setKey, address value) external onlyController {
        addressSets[setKey].add(value);
    }

    // @dev remove the given value from the set
    // @param setKey the key of the set
    // @param value the value to remove
    function removeAddress(bytes32 setKey, address value) external onlyController {
        addressSets[setKey].remove(value);
    }

    // @dev check whether the given value exists in the set
    // @param setKey the key of the set
    // @param value the value to check
    function containsUint(bytes32 setKey, uint256 value) external view returns (bool) {
        return uintSets[setKey].contains(value);
    }

    // @dev get the length of the set
    // @param setKey the key of the set
    function getUintCount(bytes32 setKey) external view returns (uint256) {
        return uintSets[setKey].length();
    }

    // @dev get the values of the set in the given range
    // @param setKey the key of the set
    // @param the start of the range, values at the start index will be returned
    // in the result
    // @param the end of the range, values at the end index will not be returned
    // in the result
    function getUintValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (uint256[] memory) {
        return uintSets[setKey].valuesAt(start, end);
    }

    // @dev add the given value to the set
    // @param setKey the key of the set
    // @param value the value to add
    function addUint(bytes32 setKey, uint256 value) external onlyController {
        uintSets[setKey].add(value);
    }

    // @dev remove the given value from the set
    // @param setKey the key of the set
    // @param value the value to remove
    function removeUint(bytes32 setKey, uint256 value) external onlyController {
        uintSets[setKey].remove(value);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// @title Keys
// @dev Keys for values in the DataStore
library Keys {
    // @dev key for the address of the wrapped native token
    bytes32 public constant WNT = keccak256(abi.encode("WNT"));
    // @dev key for the nonce value used in NonceUtils
    bytes32 public constant NONCE = keccak256(abi.encode("NONCE"));

    // @dev for sending received fees
    bytes32 public constant FEE_RECEIVER = keccak256(abi.encode("FEE_RECEIVER"));

    // @dev for holding tokens that could not be sent out
    bytes32 public constant HOLDING_ADDRESS = keccak256(abi.encode("HOLDING_ADDRESS"));

    // @dev key for the minimum gas that should be forwarded for execution error handling
    bytes32 public constant MIN_HANDLE_EXECUTION_ERROR_GAS = keccak256(abi.encode("MIN_HANDLE_EXECUTION_ERROR_GAS"));

    // @dev for a global reentrancy guard
    bytes32 public constant REENTRANCY_GUARD_STATUS = keccak256(abi.encode("REENTRANCY_GUARD_STATUS"));

    // @dev key for deposit fees
    bytes32 public constant DEPOSIT_FEE_TYPE = keccak256(abi.encode("DEPOSIT_FEE_TYPE"));
    // @dev key for withdrawal fees
    bytes32 public constant WITHDRAWAL_FEE_TYPE = keccak256(abi.encode("WITHDRAWAL_FEE_TYPE"));
    // @dev key for swap fees
    bytes32 public constant SWAP_FEE_TYPE = keccak256(abi.encode("SWAP_FEE_TYPE"));
    // @dev key for position fees
    bytes32 public constant POSITION_FEE_TYPE = keccak256(abi.encode("POSITION_FEE_TYPE"));
    // @dev key for ui deposit fees
    bytes32 public constant UI_DEPOSIT_FEE_TYPE = keccak256(abi.encode("UI_DEPOSIT_FEE_TYPE"));
    // @dev key for ui withdrawal fees
    bytes32 public constant UI_WITHDRAWAL_FEE_TYPE = keccak256(abi.encode("UI_WITHDRAWAL_FEE_TYPE"));
    // @dev key for ui swap fees
    bytes32 public constant UI_SWAP_FEE_TYPE = keccak256(abi.encode("UI_SWAP_FEE_TYPE"));
    // @dev key for ui position fees
    bytes32 public constant UI_POSITION_FEE_TYPE = keccak256(abi.encode("UI_POSITION_FEE_TYPE"));

    // @dev key for ui fee factor
    bytes32 public constant UI_FEE_FACTOR = keccak256(abi.encode("UI_FEE_FACTOR"));
    // @dev key for max ui fee receiver factor
    bytes32 public constant MAX_UI_FEE_FACTOR = keccak256(abi.encode("MAX_UI_FEE_FACTOR"));

    // @dev key for the claimable fee amount
    bytes32 public constant CLAIMABLE_FEE_AMOUNT = keccak256(abi.encode("CLAIMABLE_FEE_AMOUNT"));
    // @dev key for the claimable ui fee amount
    bytes32 public constant CLAIMABLE_UI_FEE_AMOUNT = keccak256(abi.encode("CLAIMABLE_UI_FEE_AMOUNT"));

    // @dev key for the market list
    bytes32 public constant MARKET_LIST = keccak256(abi.encode("MARKET_LIST"));

    // @dev key for the deposit list
    bytes32 public constant DEPOSIT_LIST = keccak256(abi.encode("DEPOSIT_LIST"));
    // @dev key for the account deposit list
    bytes32 public constant ACCOUNT_DEPOSIT_LIST = keccak256(abi.encode("ACCOUNT_DEPOSIT_LIST"));

    // @dev key for the withdrawal list
    bytes32 public constant WITHDRAWAL_LIST = keccak256(abi.encode("WITHDRAWAL_LIST"));
    // @dev key for the account withdrawal list
    bytes32 public constant ACCOUNT_WITHDRAWAL_LIST = keccak256(abi.encode("ACCOUNT_WITHDRAWAL_LIST"));

    // @dev key for the position list
    bytes32 public constant POSITION_LIST = keccak256(abi.encode("POSITION_LIST"));
    // @dev key for the account position list
    bytes32 public constant ACCOUNT_POSITION_LIST = keccak256(abi.encode("ACCOUNT_POSITION_LIST"));

    // @dev key for the order list
    bytes32 public constant ORDER_LIST = keccak256(abi.encode("ORDER_LIST"));
    // @dev key for the account order list
    bytes32 public constant ACCOUNT_ORDER_LIST = keccak256(abi.encode("ACCOUNT_ORDER_LIST"));

    // @dev key for is market disabled
    bytes32 public constant IS_MARKET_DISABLED = keccak256(abi.encode("IS_MARKET_DISABLED"));

    // @dev key for the max swap path length allowed
    bytes32 public constant MAX_SWAP_PATH_LENGTH = keccak256(abi.encode("MAX_SWAP_PATH_LENGTH"));
    // @dev key used to store markets observed in a swap path, to ensure that a swap path contains unique markets
    bytes32 public constant SWAP_PATH_MARKET_FLAG = keccak256(abi.encode("SWAP_PATH_MARKET_FLAG"));

    // @dev key for whether the create deposit feature is disabled
    bytes32 public constant CREATE_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("CREATE_DEPOSIT_FEATURE_DISABLED"));
    // @dev key for whether the cancel deposit feature is disabled
    bytes32 public constant CANCEL_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_DEPOSIT_FEATURE_DISABLED"));
    // @dev key for whether the execute deposit feature is disabled
    bytes32 public constant EXECUTE_DEPOSIT_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_DEPOSIT_FEATURE_DISABLED"));

    // @dev key for whether the create withdrawal feature is disabled
    bytes32 public constant CREATE_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("CREATE_WITHDRAWAL_FEATURE_DISABLED"));
    // @dev key for whether the cancel withdrawal feature is disabled
    bytes32 public constant CANCEL_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_WITHDRAWAL_FEATURE_DISABLED"));
    // @dev key for whether the execute withdrawal feature is disabled
    bytes32 public constant EXECUTE_WITHDRAWAL_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_WITHDRAWAL_FEATURE_DISABLED"));

    // @dev key for whether the create order feature is disabled
    bytes32 public constant CREATE_ORDER_FEATURE_DISABLED = keccak256(abi.encode("CREATE_ORDER_FEATURE_DISABLED"));
    // @dev key for whether the execute order feature is disabled
    bytes32 public constant EXECUTE_ORDER_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_ORDER_FEATURE_DISABLED"));
    // @dev key for whether the execute adl feature is disabled
    // for liquidations, it can be disabled by using the EXECUTE_ORDER_FEATURE_DISABLED key with the Liquidation
    // order type, ADL orders have a MarketDecrease order type, so a separate key is needed to disable it
    bytes32 public constant EXECUTE_ADL_FEATURE_DISABLED = keccak256(abi.encode("EXECUTE_ADL_FEATURE_DISABLED"));
    // @dev key for whether the update order feature is disabled
    bytes32 public constant UPDATE_ORDER_FEATURE_DISABLED = keccak256(abi.encode("UPDATE_ORDER_FEATURE_DISABLED"));
    // @dev key for whether the cancel order feature is disabled
    bytes32 public constant CANCEL_ORDER_FEATURE_DISABLED = keccak256(abi.encode("CANCEL_ORDER_FEATURE_DISABLED"));

    // @dev key for whether the claim funding fees feature is disabled
    bytes32 public constant CLAIM_FUNDING_FEES_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_FUNDING_FEES_FEATURE_DISABLED"));
    // @dev key for whether the claim collateral feature is disabled
    bytes32 public constant CLAIM_COLLATERAL_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_COLLATERAL_FEATURE_DISABLED"));
    // @dev key for whether the claim affiliate rewards feature is disabled
    bytes32 public constant CLAIM_AFFILIATE_REWARDS_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_AFFILIATE_REWARDS_FEATURE_DISABLED"));
    // @dev key for whether the claim ui fees feature is disabled
    bytes32 public constant CLAIM_UI_FEES_FEATURE_DISABLED = keccak256(abi.encode("CLAIM_UI_FEES_FEATURE_DISABLED"));

    // @dev key for the minimum required oracle signers for an oracle observation
    bytes32 public constant MIN_ORACLE_SIGNERS = keccak256(abi.encode("MIN_ORACLE_SIGNERS"));
    // @dev key for the minimum block confirmations before blockhash can be excluded for oracle signature validation
    bytes32 public constant MIN_ORACLE_BLOCK_CONFIRMATIONS = keccak256(abi.encode("MIN_ORACLE_BLOCK_CONFIRMATIONS"));
    // @dev key for the maximum usable oracle price age in seconds
    bytes32 public constant MAX_ORACLE_PRICE_AGE = keccak256(abi.encode("MAX_ORACLE_PRICE_AGE"));
    // @dev key for the maximum oracle price deviation factor from the ref price
    bytes32 public constant MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR = keccak256(abi.encode("MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR"));
    // @dev key for the percentage amount of position fees to be received
    bytes32 public constant POSITION_FEE_RECEIVER_FACTOR = keccak256(abi.encode("POSITION_FEE_RECEIVER_FACTOR"));
    // @dev key for the percentage amount of swap fees to be received
    bytes32 public constant SWAP_FEE_RECEIVER_FACTOR = keccak256(abi.encode("SWAP_FEE_RECEIVER_FACTOR"));
    // @dev key for the percentage amount of borrowing fees to be received
    bytes32 public constant BORROWING_FEE_RECEIVER_FACTOR = keccak256(abi.encode("BORROWING_FEE_RECEIVER_FACTOR"));

    // @dev key for the base gas limit used when estimating execution fee
    bytes32 public constant ESTIMATED_GAS_FEE_BASE_AMOUNT = keccak256(abi.encode("ESTIMATED_GAS_FEE_BASE_AMOUNT"));
    // @dev key for the multiplier used when estimating execution fee
    bytes32 public constant ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR = keccak256(abi.encode("ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR"));

    // @dev key for the base gas limit used when calculating execution fee
    bytes32 public constant EXECUTION_GAS_FEE_BASE_AMOUNT = keccak256(abi.encode("EXECUTION_GAS_FEE_BASE_AMOUNT"));
    // @dev key for the multiplier used when calculating execution fee
    bytes32 public constant EXECUTION_GAS_FEE_MULTIPLIER_FACTOR = keccak256(abi.encode("EXECUTION_GAS_FEE_MULTIPLIER_FACTOR"));

    // @dev key for the estimated gas limit for deposits
    bytes32 public constant DEPOSIT_GAS_LIMIT = keccak256(abi.encode("DEPOSIT_GAS_LIMIT"));
    // @dev key for the estimated gas limit for withdrawals
    bytes32 public constant WITHDRAWAL_GAS_LIMIT = keccak256(abi.encode("WITHDRAWAL_GAS_LIMIT"));
    // @dev key for the estimated gas limit for single swaps
    bytes32 public constant SINGLE_SWAP_GAS_LIMIT = keccak256(abi.encode("SINGLE_SWAP_GAS_LIMIT"));
    // @dev key for the estimated gas limit for increase orders
    bytes32 public constant INCREASE_ORDER_GAS_LIMIT = keccak256(abi.encode("INCREASE_ORDER_GAS_LIMIT"));
    // @dev key for the estimated gas limit for decrease orders
    bytes32 public constant DECREASE_ORDER_GAS_LIMIT = keccak256(abi.encode("DECREASE_ORDER_GAS_LIMIT"));
    // @dev key for the estimated gas limit for swap orders
    bytes32 public constant SWAP_ORDER_GAS_LIMIT = keccak256(abi.encode("SWAP_ORDER_GAS_LIMIT"));
    // @dev key for the amount of gas to forward for token transfers
    bytes32 public constant TOKEN_TRANSFER_GAS_LIMIT = keccak256(abi.encode("TOKEN_TRANSFER_GAS_LIMIT"));
    // @dev key for the amount of gas to forward for native token transfers
    bytes32 public constant NATIVE_TOKEN_TRANSFER_GAS_LIMIT = keccak256(abi.encode("NATIVE_TOKEN_TRANSFER_GAS_LIMIT"));
    // @dev key for the maximum request block age, after which the request will be considered expired
    bytes32 public constant REQUEST_EXPIRATION_BLOCK_AGE = keccak256(abi.encode("REQUEST_EXPIRATION_BLOCK_AGE"));

    bytes32 public constant MAX_CALLBACK_GAS_LIMIT = keccak256(abi.encode("MAX_CALLBACK_GAS_LIMIT"));
    bytes32 public constant SAVED_CALLBACK_CONTRACT = keccak256(abi.encode("SAVED_CALLBACK_CONTRACT"));

    // @dev key for the min collateral factor
    bytes32 public constant MIN_COLLATERAL_FACTOR = keccak256(abi.encode("MIN_COLLATERAL_FACTOR"));
    // @dev key for the min collateral factor for open interest multiplier
    bytes32 public constant MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER = keccak256(abi.encode("MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER"));
    // @dev key for the min allowed collateral in USD
    bytes32 public constant MIN_COLLATERAL_USD = keccak256(abi.encode("MIN_COLLATERAL_USD"));
    // @dev key for the min allowed position size in USD
    bytes32 public constant MIN_POSITION_SIZE_USD = keccak256(abi.encode("MIN_POSITION_SIZE_USD"));

    // @dev key for the virtual id of tokens
    bytes32 public constant VIRTUAL_TOKEN_ID = keccak256(abi.encode("VIRTUAL_TOKEN_ID"));
    // @dev key for the virtual id of markets
    bytes32 public constant VIRTUAL_MARKET_ID = keccak256(abi.encode("VIRTUAL_MARKET_ID"));
    // @dev key for the virtual inventory for swaps
    bytes32 public constant VIRTUAL_INVENTORY_FOR_SWAPS = keccak256(abi.encode("VIRTUAL_INVENTORY_FOR_SWAPS"));
    // @dev key for the virtual inventory for positions
    bytes32 public constant VIRTUAL_INVENTORY_FOR_POSITIONS = keccak256(abi.encode("VIRTUAL_INVENTORY_FOR_POSITIONS"));

    // @dev key for the position impact factor
    bytes32 public constant POSITION_IMPACT_FACTOR = keccak256(abi.encode("POSITION_IMPACT_FACTOR"));
    // @dev key for the position impact exponent factor
    bytes32 public constant POSITION_IMPACT_EXPONENT_FACTOR = keccak256(abi.encode("POSITION_IMPACT_EXPONENT_FACTOR"));
    // @dev key for the max decrease position impact factor
    bytes32 public constant MAX_POSITION_IMPACT_FACTOR = keccak256(abi.encode("MAX_POSITION_IMPACT_FACTOR"));
    // @dev key for the max position impact factor for liquidations
    bytes32 public constant MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS = keccak256(abi.encode("MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS"));
    // @dev key for the position fee factor
    bytes32 public constant POSITION_FEE_FACTOR = keccak256(abi.encode("POSITION_FEE_FACTOR"));
    // @dev key for the swap impact factor
    bytes32 public constant SWAP_IMPACT_FACTOR = keccak256(abi.encode("SWAP_IMPACT_FACTOR"));
    // @dev key for the swap impact exponent factor
    bytes32 public constant SWAP_IMPACT_EXPONENT_FACTOR = keccak256(abi.encode("SWAP_IMPACT_EXPONENT_FACTOR"));
    // @dev key for the swap fee factor
    bytes32 public constant SWAP_FEE_FACTOR = keccak256(abi.encode("SWAP_FEE_FACTOR"));
    // @dev key for the oracle type
    bytes32 public constant ORACLE_TYPE = keccak256(abi.encode("ORACLE_TYPE"));
    // @dev key for open interest
    bytes32 public constant OPEN_INTEREST = keccak256(abi.encode("OPEN_INTEREST"));
    // @dev key for open interest in tokens
    bytes32 public constant OPEN_INTEREST_IN_TOKENS = keccak256(abi.encode("OPEN_INTEREST_IN_TOKENS"));
    // @dev key for collateral sum for a market
    bytes32 public constant COLLATERAL_SUM = keccak256(abi.encode("COLLATERAL_SUM"));
    // @dev key for pool amount
    bytes32 public constant POOL_AMOUNT = keccak256(abi.encode("POOL_AMOUNT"));
    // @dev key for max pool amount
    bytes32 public constant MAX_POOL_AMOUNT = keccak256(abi.encode("MAX_POOL_AMOUNT"));
    // @dev key for max open interest
    bytes32 public constant MAX_OPEN_INTEREST = keccak256(abi.encode("MAX_OPEN_INTEREST"));
    // @dev key for position impact pool amount
    bytes32 public constant POSITION_IMPACT_POOL_AMOUNT = keccak256(abi.encode("POSITION_IMPACT_POOL_AMOUNT"));
    // @dev key for swap impact pool amount
    bytes32 public constant SWAP_IMPACT_POOL_AMOUNT = keccak256(abi.encode("SWAP_IMPACT_POOL_AMOUNT"));
    // @dev key for price feed
    bytes32 public constant PRICE_FEED = keccak256(abi.encode("PRICE_FEED"));
    // @dev key for price feed multiplier
    bytes32 public constant PRICE_FEED_MULTIPLIER = keccak256(abi.encode("PRICE_FEED_MULTIPLIER"));
    // @dev key for price feed heartbeat
    bytes32 public constant PRICE_FEED_HEARTBEAT_DURATION = keccak256(abi.encode("PRICE_FEED_HEARTBEAT_DURATION"));
    // @dev key for stable price
    bytes32 public constant STABLE_PRICE = keccak256(abi.encode("STABLE_PRICE"));
    // @dev key for reserve factor
    bytes32 public constant RESERVE_FACTOR = keccak256(abi.encode("RESERVE_FACTOR"));
    // @dev key for open interest reserve factor
    bytes32 public constant OPEN_INTEREST_RESERVE_FACTOR = keccak256(abi.encode("OPEN_INTEREST_RESERVE_FACTOR"));
    // @dev key for max pnl factor
    bytes32 public constant MAX_PNL_FACTOR = keccak256(abi.encode("MAX_PNL_FACTOR"));
    // @dev key for max pnl factor
    bytes32 public constant MAX_PNL_FACTOR_FOR_TRADERS = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_TRADERS"));
    // @dev key for max pnl factor for adl
    bytes32 public constant MAX_PNL_FACTOR_FOR_ADL = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_ADL"));
    // @dev key for min pnl factor for adl
    bytes32 public constant MIN_PNL_FACTOR_AFTER_ADL = keccak256(abi.encode("MIN_PNL_FACTOR_AFTER_ADL"));
    // @dev key for max pnl factor
    bytes32 public constant MAX_PNL_FACTOR_FOR_DEPOSITS = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_DEPOSITS"));
    // @dev key for max pnl factor for withdrawals
    bytes32 public constant MAX_PNL_FACTOR_FOR_WITHDRAWALS = keccak256(abi.encode("MAX_PNL_FACTOR_FOR_WITHDRAWALS"));
    // @dev key for latest ADL block
    bytes32 public constant LATEST_ADL_BLOCK = keccak256(abi.encode("LATEST_ADL_BLOCK"));
    // @dev key for whether ADL is enabled
    bytes32 public constant IS_ADL_ENABLED = keccak256(abi.encode("IS_ADL_ENABLED"));
    // @dev key for funding factor
    bytes32 public constant FUNDING_FACTOR = keccak256(abi.encode("FUNDING_FACTOR"));
    // @dev key for stable funding factor
    bytes32 public constant STABLE_FUNDING_FACTOR = keccak256(abi.encode("STABLE_FUNDING_FACTOR"));
    // @dev key for funding exponent factor
    bytes32 public constant FUNDING_EXPONENT_FACTOR = keccak256(abi.encode("FUNDING_EXPONENT_FACTOR"));
    // @dev key for funding fee amount per size
    bytes32 public constant FUNDING_FEE_AMOUNT_PER_SIZE = keccak256(abi.encode("FUNDING_FEE_AMOUNT_PER_SIZE"));
    // @dev key for claimable funding amount per size
    bytes32 public constant CLAIMABLE_FUNDING_AMOUNT_PER_SIZE = keccak256(abi.encode("CLAIMABLE_FUNDING_AMOUNT_PER_SIZE"));
    // @dev key for when funding was last updated at
    bytes32 public constant FUNDING_UPDATED_AT = keccak256(abi.encode("FUNDING_UPDATED_AT"));
    // @dev key for claimable funding amount
    bytes32 public constant CLAIMABLE_FUNDING_AMOUNT = keccak256(abi.encode("CLAIMABLE_FUNDING_AMOUNT"));
    // @dev key for claimable collateral amount
    bytes32 public constant CLAIMABLE_COLLATERAL_AMOUNT = keccak256(abi.encode("CLAIMABLE_COLLATERAL_AMOUNT"));
    // @dev key for claimable collateral factor
    bytes32 public constant CLAIMABLE_COLLATERAL_FACTOR = keccak256(abi.encode("CLAIMABLE_COLLATERAL_FACTOR"));
    // @dev key for claimable collateral time divisor
    bytes32 public constant CLAIMABLE_COLLATERAL_TIME_DIVISOR = keccak256(abi.encode("CLAIMABLE_COLLATERAL_TIME_DIVISOR"));
    // @dev key for claimed collateral amount
    bytes32 public constant CLAIMED_COLLATERAL_AMOUNT = keccak256(abi.encode("CLAIMED_COLLATERAL_AMOUNT"));
    // @dev key for borrowing factor
    bytes32 public constant BORROWING_FACTOR = keccak256(abi.encode("BORROWING_FACTOR"));
    // @dev key for borrowing factor
    bytes32 public constant BORROWING_EXPONENT_FACTOR = keccak256(abi.encode("BORROWING_EXPONENT_FACTOR"));
    // @dev key for skipping the borrowing factor for the smaller side
    bytes32 public constant SKIP_BORROWING_FEE_FOR_SMALLER_SIDE = keccak256(abi.encode("SKIP_BORROWING_FEE_FOR_SMALLER_SIDE"));
    // @dev key for cumulative borrowing factor
    bytes32 public constant CUMULATIVE_BORROWING_FACTOR = keccak256(abi.encode("CUMULATIVE_BORROWING_FACTOR"));
    // @dev key for when the cumulative borrowing factor was last updated at
    bytes32 public constant CUMULATIVE_BORROWING_FACTOR_UPDATED_AT = keccak256(abi.encode("CUMULATIVE_BORROWING_FACTOR_UPDATED_AT"));
    // @dev key for total borrowing amount
    bytes32 public constant TOTAL_BORROWING = keccak256(abi.encode("TOTAL_BORROWING"));
    // @dev key for affiliate reward
    bytes32 public constant AFFILIATE_REWARD = keccak256(abi.encode("AFFILIATE_REWARD"));

    // @dev constant for user initiated cancel reason
    string public constant USER_INITIATED_CANCEL = "USER_INITIATED_CANCEL";

    // @dev key for the account deposit list
    // @param account the account for the list
    function accountDepositListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_DEPOSIT_LIST, account));
    }

    // @dev key for the account withdrawal list
    // @param account the account for the list
    function accountWithdrawalListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_WITHDRAWAL_LIST, account));
    }

    // @dev key for the account position list
    // @param account the account for the list
    function accountPositionListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_POSITION_LIST, account));
    }

    // @dev key for the account order list
    // @param account the account for the list
    function accountOrderListKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(ACCOUNT_ORDER_LIST, account));
    }

    // @dev key for the claimable fee amount
    // @param market the market for the fee
    // @param token the token for the fee
    function claimableFeeAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLAIMABLE_FEE_AMOUNT, market, token));
    }

    // @dev key for the claimable ui fee amount
    // @param market the market for the fee
    // @param token the token for the fee
    // @param account the account that can claim the ui fee
    function claimableUiFeeAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLAIMABLE_UI_FEE_AMOUNT, market, token));
    }

    // @dev key for the claimable ui fee amount for account
    // @param market the market for the fee
    // @param token the token for the fee
    // @param account the account that can claim the ui fee
    function claimableUiFeeAmountKey(address market, address token, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(CLAIMABLE_UI_FEE_AMOUNT, market, token, account));
    }

    // @dev key for deposit gas limit
    // @param singleToken whether a single token or pair tokens are being deposited
    // @return key for deposit gas limit
    function depositGasLimitKey(bool singleToken) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            DEPOSIT_GAS_LIMIT,
            singleToken
        ));
    }

    // @dev key for withdrawal gas limit
    // @return key for withdrawal gas limit
    function withdrawalGasLimitKey() internal pure returns (bytes32) {
        return keccak256(abi.encode(
            WITHDRAWAL_GAS_LIMIT
        ));
    }

    // @dev key for single swap gas limit
    // @return key for single swap gas limit
    function singleSwapGasLimitKey() internal pure returns (bytes32) {
        return SINGLE_SWAP_GAS_LIMIT;
    }

    // @dev key for increase order gas limit
    // @return key for increase order gas limit
    function increaseOrderGasLimitKey() internal pure returns (bytes32) {
        return INCREASE_ORDER_GAS_LIMIT;
    }

    // @dev key for decrease order gas limit
    // @return key for decrease order gas limit
    function decreaseOrderGasLimitKey() internal pure returns (bytes32) {
        return DECREASE_ORDER_GAS_LIMIT;
    }

    // @dev key for swap order gas limit
    // @return key for swap order gas limit
    function swapOrderGasLimitKey() internal pure returns (bytes32) {
        return SWAP_ORDER_GAS_LIMIT;
    }

    function swapPathMarketFlagKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_PATH_MARKET_FLAG,
            market
        ));
    }

    // @dev key for whether create deposit is disabled
    // @param the create deposit module
    // @return key for whether create deposit is disabled
    function createDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether cancel deposit is disabled
    // @param the cancel deposit module
    // @return key for whether cancel deposit is disabled
    function cancelDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute deposit is disabled
    // @param the execute deposit module
    // @return key for whether execute deposit is disabled
    function executeDepositFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_DEPOSIT_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether create withdrawal is disabled
    // @param the create withdrawal module
    // @return key for whether create withdrawal is disabled
    function createWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether cancel withdrawal is disabled
    // @param the cancel withdrawal module
    // @return key for whether cancel withdrawal is disabled
    function cancelWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether execute withdrawal is disabled
    // @param the execute withdrawal module
    // @return key for whether execute withdrawal is disabled
    function executeWithdrawalFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_WITHDRAWAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether create order is disabled
    // @param the create order module
    // @return key for whether create order is disabled
    function createOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CREATE_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether execute order is disabled
    // @param the execute order module
    // @return key for whether execute order is disabled
    function executeOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether execute adl is disabled
    // @param the execute adl module
    // @return key for whether execute adl is disabled
    function executeAdlFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EXECUTE_ADL_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether update order is disabled
    // @param the update order module
    // @return key for whether update order is disabled
    function updateOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            UPDATE_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether cancel order is disabled
    // @param the cancel order module
    // @return key for whether cancel order is disabled
    function cancelOrderFeatureDisabledKey(address module, uint256 orderType) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CANCEL_ORDER_FEATURE_DISABLED,
            module,
            orderType
        ));
    }

    // @dev key for whether claim funding fees is disabled
    // @param the claim funding fees module
    function claimFundingFeesFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_FUNDING_FEES_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether claim colltareral is disabled
    // @param the claim funding fees module
    function claimCollateralFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_COLLATERAL_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether claim affiliate rewards is disabled
    // @param the claim affiliate rewards module
    function claimAffiliateRewardsFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_AFFILIATE_REWARDS_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for whether claim ui fees is disabled
    // @param the claim ui fees module
    function claimUiFeesFeatureDisabledKey(address module) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIM_UI_FEES_FEATURE_DISABLED,
            module
        ));
    }

    // @dev key for ui fee factor
    // @param account the fee receiver account
    // @return key for ui fee factor
    function uiFeeFactorKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            UI_FEE_FACTOR,
            account
        ));
    }

    // @dev key for gas to forward for token transfer
    // @param the token to check
    // @return key for gas to forward for token transfer
    function tokenTransferGasLimit(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TOKEN_TRANSFER_GAS_LIMIT,
            token
        ));
   }

   // @dev the default callback contract
   // @param account the user's account
   // @param market the address of the market
   // @param callbackContract the callback contract
   function savedCallbackContract(address account, address market) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           SAVED_CALLBACK_CONTRACT,
           account,
           market
       ));
   }

   // @dev the min collateral factor key
   // @param the market for the min collateral factor
   function minCollateralFactorKey(address market) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           MIN_COLLATERAL_FACTOR,
           market
       ));
   }

   // @dev the min collateral factor for open interest multiplier key
   // @param the market for the factor
   function minCollateralFactorForOpenInterestMultiplierKey(address market, bool isLong) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER,
           market,
           isLong
       ));
   }

   // @dev the key for the virtual token id
   // @param the token to get the virtual id for
   function virtualTokenIdKey(address token) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_TOKEN_ID,
           token
       ));
   }

   // @dev the key for the virtual market id
   // @param the market to get the virtual id for
   function virtualMarketIdKey(address market) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_MARKET_ID,
           market
       ));
   }

   // @dev the key for the virtual inventory for positions
   // @param the virtualTokenId the virtual token id
   function virtualInventoryForPositionsKey(bytes32 virtualTokenId) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_INVENTORY_FOR_POSITIONS,
           virtualTokenId
       ));
   }

   // @dev the key for the virtual inventory for swaps
   // @param the virtualMarketId the virtual market id
   // @param the token to check the inventory for
   function virtualInventoryForSwapsKey(bytes32 virtualMarketId, bool isLongToken) internal pure returns (bytes32) {
       return keccak256(abi.encode(
           VIRTUAL_INVENTORY_FOR_SWAPS,
           virtualMarketId,
           isLongToken
       ));
   }

    // @dev key for position impact factor
    // @param market the market address to check
    // @param isPositive whether the impact is positive or negative
    // @return key for position impact factor
    function positionImpactFactorKey(address market, bool isPositive) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_FACTOR,
            market,
            isPositive
        ));
   }

    // @dev key for position impact exponent factor
    // @param market the market address to check
    // @return key for position impact exponent factor
    function positionImpactExponentFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_EXPONENT_FACTOR,
            market
        ));
    }

    // @dev key for the max position impact factor
    // @param market the market address to check
    // @return key for the max position impact factor
    function maxPositionImpactFactorKey(address market, bool isPositive) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_POSITION_IMPACT_FACTOR,
            market,
            isPositive
        ));
    }

    // @dev key for the max position impact factor for liquidations
    // @param market the market address to check
    // @return key for the max position impact factor
    function maxPositionImpactFactorForLiquidationsKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS,
            market
        ));
    }

    // @dev key for position fee factor
    // @param market the market address to check
    // @param forPositiveImpact whether the fee is for an action that has a positive price impact
    // @return key for position fee factor
    function positionFeeFactorKey(address market, bool forPositiveImpact) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_FEE_FACTOR,
            market,
            forPositiveImpact
        ));
    }

    // @dev key for swap impact factor
    // @param market the market address to check
    // @param isPositive whether the impact is positive or negative
    // @return key for swap impact factor
    function swapImpactFactorKey(address market, bool isPositive) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_IMPACT_FACTOR,
            market,
            isPositive
        ));
    }

    // @dev key for swap impact exponent factor
    // @param market the market address to check
    // @return key for swap impact exponent factor
    function swapImpactExponentFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_IMPACT_EXPONENT_FACTOR,
            market
        ));
    }


    // @dev key for swap fee factor
    // @param market the market address to check
    // @return key for swap fee factor
    function swapFeeFactorKey(address market, bool forPositiveImpact) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_FEE_FACTOR,
            market,
            forPositiveImpact
        ));
    }

    // @dev key for oracle type
    // @param token the token to check
    // @return key for oracle type
    function oracleTypeKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            ORACLE_TYPE,
            token
        ));
    }

    // @dev key for open interest
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short open interest
    // @return key for open interest
    function openInterestKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OPEN_INTEREST,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for open interest in tokens
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short open interest
    // @return key for open interest in tokens
    function openInterestInTokensKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OPEN_INTEREST_IN_TOKENS,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for collateral sum for a market
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short open interest
    // @return key for collateral sum
    function collateralSumKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            COLLATERAL_SUM,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for amount of tokens in a market's pool
    // @param market the market to check
    // @param token the token to check
    // @return key for amount of tokens in a market's pool
    function poolAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POOL_AMOUNT,
            market,
            token
        ));
    }

    // @dev the key for the max amount of pool tokens
    // @param market the market for the pool
    // @param token the token for the pool
    function maxPoolAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_POOL_AMOUNT,
            market,
            token
        ));
    }

    // @dev the key for the max open interest
    // @param market the market for the pool
    // @param isLong whether the key is for the long or short side
    function maxOpenInterestKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_OPEN_INTEREST,
            market,
            isLong
        ));
    }

    // @dev key for amount of tokens in a market's position impact pool
    // @param market the market to check
    // @return key for amount of tokens in a market's position impact pool
    function positionImpactPoolAmountKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            POSITION_IMPACT_POOL_AMOUNT,
            market
        ));
    }

    // @dev key for amount of tokens in a market's swap impact pool
    // @param market the market to check
    // @param token the token to check
    // @return key for amount of tokens in a market's swap impact pool
    function swapImpactPoolAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            SWAP_IMPACT_POOL_AMOUNT,
            market,
            token
        ));
    }

    // @dev key for reserve factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for reserve factor
    function reserveFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            RESERVE_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for open interest reserve factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for open interest reserve factor
    function openInterestReserveFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            OPEN_INTEREST_RESERVE_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for max pnl factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for max pnl factor
    function maxPnlFactorKey(bytes32 pnlFactorType, address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MAX_PNL_FACTOR,
            pnlFactorType,
            market,
            isLong
        ));
    }

    // @dev the key for min PnL factor after ADL
    // @param market the market for the pool
    // @param isLong whether the key is for the long or short side
    function minPnlFactorAfterAdlKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            MIN_PNL_FACTOR_AFTER_ADL,
            market,
            isLong
        ));
    }

    // @dev key for latest adl block
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for latest adl block
    function latestAdlBlockKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            LATEST_ADL_BLOCK,
            market,
            isLong
        ));
    }

    // @dev key for whether adl is enabled
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for whether adl is enabled
    function isAdlEnabledKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            IS_ADL_ENABLED,
            market,
            isLong
        ));
    }

    // @dev key for funding factor
    // @param market the market to check
    // @return key for funding factor
    function fundingFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_FACTOR,
            market
        ));
    }

    // @dev key for stable funding factor
    // @param market the market to check
    // @return key for stable funding factor
    function stableFundingFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            STABLE_FUNDING_FACTOR,
            market
        ));
    }

    // @dev the key for funding exponent
    // @param market the market for the pool
    function fundingExponentFactorKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_EXPONENT_FACTOR,
            market
        ));
    }

    // @dev key for funding fee amount per size
    // @param market the market to check
    // @param collateralToken the collateralToken to get the key for
    // @param isLong whether to get the key for the long or short side
    // @return key for funding fee amount per size
    function fundingFeeAmountPerSizeKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_FEE_AMOUNT_PER_SIZE,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for claimabel funding amount per size
    // @param market the market to check
    // @param collateralToken the collateralToken to get the key for
    // @param isLong whether to get the key for the long or short side
    // @return key for claimable funding amount per size
    function claimableFundingAmountPerSizeKey(address market, address collateralToken, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_FUNDING_AMOUNT_PER_SIZE,
            market,
            collateralToken,
            isLong
        ));
    }

    // @dev key for when funding was last updated
    // @param market the market to check
    // @return key for when funding was last updated
    function fundingUpdatedAtKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            FUNDING_UPDATED_AT,
            market
        ));
    }

    // @dev key for claimable funding amount
    // @param market the market to check
    // @param token the token to check
    // @return key for claimable funding amount
    function claimableFundingAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_FUNDING_AMOUNT,
            market,
            token
        ));
    }

    // @dev key for claimable funding amount by account
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @return key for claimable funding amount
    function claimableFundingAmountKey(address market, address token, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_FUNDING_AMOUNT,
            market,
            token,
            account
        ));
    }

    // @dev key for claimable collateral amount
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimableCollateralAmountKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_AMOUNT,
            market,
            token
        ));
    }

    // @dev key for claimable collateral amount for a timeKey for an account
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimableCollateralAmountKey(address market, address token, uint256 timeKey, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_AMOUNT,
            market,
            token,
            timeKey,
            account
        ));
    }

    // @dev key for claimable collateral factor for a timeKey
    // @param market the market to check
    // @param token the token to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimableCollateralFactorKey(address market, address token, uint256 timeKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_FACTOR,
            market,
            token,
            timeKey
        ));
    }

    // @dev key for claimable collateral factor for a timeKey for an account
    // @param market the market to check
    // @param token the token to check
    // @param timeKey the time key for the claimable amount
    // @param account the account to check
    // @return key for claimable funding amount
    function claimableCollateralFactorKey(address market, address token, uint256 timeKey, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMABLE_COLLATERAL_FACTOR,
            market,
            token,
            timeKey,
            account
        ));
    }

    // @dev key for claimable collateral factor
    // @param market the market to check
    // @param token the token to check
    // @param account the account to check
    // @param timeKey the time key for the claimable amount
    // @return key for claimable funding amount
    function claimedCollateralAmountKey(address market, address token, uint256 timeKey, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CLAIMED_COLLATERAL_AMOUNT,
            market,
            token,
            timeKey,
            account
        ));
    }

    // @dev key for borrowing factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for borrowing factor
    function borrowingFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BORROWING_FACTOR,
            market,
            isLong
        ));
    }

    // @dev the key for borrowing exponent
    // @param market the market for the pool
    // @param isLong whether to get the key for the long or short side
    function borrowingExponentFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            BORROWING_EXPONENT_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for cumulative borrowing factor
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for cumulative borrowing factor
    function cumulativeBorrowingFactorKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CUMULATIVE_BORROWING_FACTOR,
            market,
            isLong
        ));
    }

    // @dev key for cumulative borrowing factor updated at
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for cumulative borrowing factor updated at
    function cumulativeBorrowingFactorUpdatedAtKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CUMULATIVE_BORROWING_FACTOR_UPDATED_AT,
            market,
            isLong
        ));
    }

    // @dev key for total borrowing amount
    // @param market the market to check
    // @param isLong whether to get the key for the long or short side
    // @return key for total borrowing amount
    function totalBorrowingKey(address market, bool isLong) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            TOTAL_BORROWING,
            market,
            isLong
        ));
    }

    // @dev key for affiliate reward amount
    // @param market the market to check
    // @param token the token to get the key for
    // @param account the account to get the key for
    // @return key for affiliate reward amount
    function affiliateRewardKey(address market, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AFFILIATE_REWARD,
            market,
            token
        ));
    }

    // @dev key for affiliate reward amount for an account
    // @param market the market to check
    // @param token the token to get the key for
    // @param account the account to get the key for
    // @return key for affiliate reward amount
    function affiliateRewardKey(address market, address token, address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            AFFILIATE_REWARD,
            market,
            token,
            account
        ));
    }

    // @dev key for is market disabled
    // @param market the market to check
    // @return key for is market disabled
    function isMarketDisabledKey(address market) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            IS_MARKET_DISABLED,
            market
        ));
    }

    // @dev key for price feed address
    // @param token the token to get the key for
    // @return key for price feed address
    function priceFeedKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRICE_FEED,
            token
        ));
    }

    // @dev key for price feed multiplier
    // @param token the token to get the key for
    // @return key for price feed multiplier
    function priceFeedMultiplierKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRICE_FEED_MULTIPLIER,
            token
        ));
    }

    function priceFeedHeartbeatDurationKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            PRICE_FEED_HEARTBEAT_DURATION,
            token
        ));
    }

    // @dev key for stable price value
    // @param token the token to get the key for
    // @return key for stable price value
    function stablePriceKey(address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            STABLE_PRICE,
            token
        ));
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library Errors {
    // AdlUtils errors
    error InvalidSizeDeltaForAdl(uint256 sizeDeltaUsd, uint256 positionSizeInUsd);
    error AdlNotEnabled();

    // Bank errors
    error SelfTransferNotSupported(address receiver);
    error InvalidNativeTokenSender(address msgSender);

    // CallbackUtils errors
    error MaxCallbackGasLimitExceeded(uint256 callbackGasLimit, uint256 maxCallbackGasLimit);

    // Config errors
    error InvalidBaseKey(bytes32 baseKey);
    error InvalidFeeFactor(bytes32 baseKey, uint256 value);

    // Timelock errors
    error ActionAlreadySignalled();
    error ActionNotSignalled();
    error SignalTimeNotYetPassed(uint256 signalTime);
    error InvalidTimelockDelay(uint256 timelockDelay);
    error MaxTimelockDelayExceeded(uint256 timelockDelay);
    error InvalidFeeReceiver(address receiver);
    error InvalidOracleSigner(address receiver);

    // DepositStoreUtils errors
    error DepositNotFound(bytes32 key);

    // DepositUtils errors
    error EmptyDeposit();
    error EmptyDepositAmounts();

    // ExecuteDepositUtils errors
    error MinMarketTokens(uint256 received, uint256 expected);
    error EmptyDepositAmountsAfterSwap();
    error InvalidPoolValueForDeposit(int256 poolValue);
    error InvalidSwapOutputToken(address outputToken, address expectedOutputToken);

    // AdlHandler errors
    error AdlNotRequired(int256 pnlToPoolFactor, uint256 maxPnlFactorForAdl);
    error InvalidAdl(int256 nextPnlToPoolFactor, int256 pnlToPoolFactor);
    error PnlOvercorrected(int256 nextPnlToPoolFactor, uint256 minPnlFactorForAdl);

    // ExchangeUtils errors
    error RequestNotYetCancellable(uint256 requestAge, uint256 requestExpirationAge, string requestType);

    // OrderHandler errors
    error OrderNotUpdatable(uint256 orderType);
    error InvalidKeeperForFrozenOrder(address keeper);

    // FeatureUtils errors
    error DisabledFeature(bytes32 key);

    // FeeHandler errors
    error InvalidClaimFeesInput(uint256 marketsLength, uint256 tokensLength);

    // GasUtils errors
    error InsufficientExecutionFee(uint256 minExecutionFee, uint256 executionFee);
    error InsufficientWntAmountForExecutionFee(uint256 wntAmount, uint256 executionFee);
    error InsufficientExecutionGas(uint256 startingGas, uint256 minHandleErrorGas);

    // MarketFactory errors
    error MarketAlreadyExists(bytes32 salt, address existingMarketAddress);

    // MarketStoreUtils errors
    error MarketNotFound(address key);

    // MarketUtils errors
    error EmptyMarket();
    error DisabledMarket(address market);
    error MaxSwapPathLengthExceeded(uint256 swapPathLengh, uint256 maxSwapPathLength);
    error InsufficientPoolAmount(uint256 poolAmount, uint256 amount);
    error InsufficientReserve(uint256 reservedUsd, uint256 maxReservedUsd);
    error InsufficientReserveForOpenInterest(uint256 reservedUsd, uint256 maxReservedUsd);
    error UnableToGetOppositeToken(address inputToken, address market);
    error UnexpectedTokenForVirtualInventory(address token, address market);
    error EmptyMarketTokenSupply();
    error InvalidSwapMarket(address market);
    error UnableToGetCachedTokenPrice(address token, address market);
    error CollateralAlreadyClaimed(uint256 adjustedClaimableAmount, uint256 claimedAmount);
    error OpenInterestCannotBeUpdatedForSwapOnlyMarket(address market);
    error MaxOpenInterestExceeded(uint256 openInterest, uint256 maxOpenInterest);
    error MaxPoolAmountExceeded(uint256 poolAmount, uint256 maxPoolAmount);
    error UnexpectedBorrowingFactor(uint256 positionBorrowingFactor, uint256 cumulativeBorrowingFactor);
    error UnableToGetBorrowingFactorEmptyPoolUsd();
    error UnableToGetFundingFactorEmptyOpenInterest();
    error InvalidPositionMarket(address market);
    error InvalidCollateralTokenForMarket(address market, address token);
    error PnlFactorExceededForLongs(int256 pnlToPoolFactor, uint256 maxPnlFactor);
    error PnlFactorExceededForShorts(int256 pnlToPoolFactor, uint256 maxPnlFactor);
    error InvalidUiFeeFactor(uint256 uiFeeFactor, uint256 maxUiFeeFactor);
    error EmptyAddressInMarketTokenBalanceValidation(address market, address token);
    error InvalidMarketTokenBalance(address market, address token, uint256 balance, uint256 expectedMinBalance);
    error InvalidMarketTokenBalanceForCollateralAmount(address market, address token, uint256 balance, uint256 collateralAmount);
    error InvalidMarketTokenBalanceForClaimableFunding(address market, address token, uint256 balance, uint256 claimableFundingFeeAmount);
    error UnexpectedPoolValue(int256 poolValue);

    // Oracle errors
    error EmptySigner(uint256 signerIndex);
    error InvalidBlockNumber(uint256 minOracleBlockNumber, uint256 currentBlockNumber);
    error InvalidMinMaxBlockNumber(uint256 minOracleBlockNumber, uint256 maxOracleBlockNumber);
    error MaxPriceAgeExceeded(uint256 oracleTimestamp, uint256 currentTimestamp);
    error MinOracleSigners(uint256 oracleSigners, uint256 minOracleSigners);
    error MaxOracleSigners(uint256 oracleSigners, uint256 maxOracleSigners);
    error BlockNumbersNotSorted(uint256 minOracleBlockNumber, uint256 prevMinOracleBlockNumber);
    error MinPricesNotSorted(address token, uint256 price, uint256 prevPrice);
    error MaxPricesNotSorted(address token, uint256 price, uint256 prevPrice);
    error EmptyPriceFeedMultiplier(address token);
    error InvalidFeedPrice(address token, int256 price);
    error PriceFeedNotUpdated(address token, uint256 timestamp, uint256 heartbeatDuration);
    error MaxSignerIndex(uint256 signerIndex, uint256 maxSignerIndex);
    error InvalidOraclePrice(address token);
    error InvalidSignerMinMaxPrice(uint256 minPrice, uint256 maxPrice);
    error InvalidMedianMinMaxPrice(uint256 minPrice, uint256 maxPrice);
    error DuplicateTokenPrice(address token);
    error NonEmptyTokensWithPrices(uint256 tokensWithPricesLength);
    error EmptyPriceFeed(address token);
    error PriceAlreadySet(address token, uint256 minPrice, uint256 maxPrice);
    error MaxRefPriceDeviationExceeded(
        address token,
        uint256 price,
        uint256 refPrice,
        uint256 maxRefPriceDeviationFactor
    );

    // OracleModule errors
    error InvalidPrimaryPricesForSimulation(uint256 primaryTokensLength, uint256 primaryPricesLength);
    error EndOfOracleSimulation();

    // OracleUtils errors
    error EmptyCompactedPrice(uint256 index);
    error EmptyCompactedBlockNumber(uint256 index);
    error EmptyCompactedTimestamp(uint256 index);
    error InvalidSignature(address recoveredSigner, address expectedSigner);

    error EmptyPrimaryPrice(address token);

    error OracleBlockNumbersAreSmallerThanRequired(uint256[] oracleBlockNumbers, uint256 expectedBlockNumber);
    error OracleBlockNumberNotWithinRange(
        uint256[] minOracleBlockNumbers,
        uint256[] maxOracleBlockNumbers,
        uint256 blockNumber
    );

    // BaseOrderUtils errors
    error EmptyOrder();
    error UnsupportedOrderType();
    error InvalidOrderPrices(
        uint256 primaryPriceMin,
        uint256 primaryPriceMax,
        uint256 triggerPrice,
        uint256 orderType
    );
    error EmptySizeDeltaInTokens();
    error PriceImpactLargerThanOrderSize(int256 priceImpactUsd, uint256 sizeDeltaUsd);
    error NegativeExecutionPrice(int256 executionPrice, uint256 price, uint256 positionSizeInUsd, int256 priceImpactUsd, uint256 sizeDeltaUsd);
    error OrderNotFulfillableAtAcceptablePrice(uint256 price, uint256 acceptablePrice);

    // IncreaseOrderUtils errors
    error UnexpectedPositionState();

    // OrderUtils errors
    error OrderTypeCannotBeCreated(uint256 orderType);
    error OrderAlreadyFrozen();

    // OrderStoreUtils errors
    error OrderNotFound(bytes32 key);

    // SwapOrderUtils errors
    error UnexpectedMarket();

    // DecreasePositionCollateralUtils errors
    error InsufficientFundsToPayForCosts(uint256 remainingCostUsd, string step);
    error InvalidOutputToken(address tokenOut, address expectedTokenOut);

    // DecreasePositionUtils errors
    error InvalidDecreaseOrderSize(uint256 sizeDeltaUsd, uint256 positionSizeInUsd);
    error UnableToWithdrawCollateral(int256 estimatedRemainingCollateralUsd);
    error InvalidDecreasePositionSwapType(uint256 decreasePositionSwapType);
    error PositionShouldNotBeLiquidated();

    // IncreasePositionUtils errors
    error InsufficientCollateralAmount(uint256 collateralAmount, int256 collateralDeltaAmount);
    error InsufficientCollateralUsd(int256 remainingCollateralUsd);

    // PositionStoreUtils errors
    error PositionNotFound(bytes32 key);

    // PositionUtils errors
    error LiquidatablePosition(string reason);
    error EmptyPosition();
    error InvalidPositionSizeValues(uint256 sizeInUsd, uint256 sizeInTokens);
    error MinPositionSize(uint256 positionSizeInUsd, uint256 minPositionSizeUsd);

    // PositionPricingUtils errors
    error UsdDeltaExceedsLongOpenInterest(int256 usdDelta, uint256 longOpenInterest);
    error UsdDeltaExceedsShortOpenInterest(int256 usdDelta, uint256 shortOpenInterest);

    // SwapPricingUtils errors
    error UsdDeltaExceedsPoolValue(int256 usdDelta, uint256 poolUsd);

    // RoleModule errors
    error Unauthorized(address msgSender, string role);

    // RoleStore errors
    error ThereMustBeAtLeastOneRoleAdmin();
    error ThereMustBeAtLeastOneTimelockMultiSig();

    // ExchangeRouter errors
    error InvalidClaimFundingFeesInput(uint256 marketsLength, uint256 tokensLength);
    error InvalidClaimCollateralInput(uint256 marketsLength, uint256 tokensLength, uint256 timeKeysLength);
    error InvalidClaimAffiliateRewardsInput(uint256 marketsLength, uint256 tokensLength);
    error InvalidClaimUiFeesInput(uint256 marketsLength, uint256 tokensLength);

    // SwapUtils errors
    error InvalidTokenIn(address tokenIn, address market);
    error InsufficientOutputAmount(uint256 outputAmount, uint256 minOutputAmount);
    error InsufficientSwapOutputAmount(uint256 outputAmount, uint256 minOutputAmount);
    error DuplicatedMarketInSwapPath(address market);
    error SwapPriceImpactExceedsAmountIn(uint256 amountAfterFees, int256 negativeImpactAmount);

    // TokenUtils errors
    error EmptyTokenTranferGasLimit(address token);
    error TokenTransferError(address token, address receiver, uint256 amount);
    error EmptyHoldingAddress();

    // AccountUtils errors
    error EmptyAccount();
    error EmptyReceiver();

    // Array errors
    error CompactedArrayOutOfBounds(
        uint256[] compactedValues,
        uint256 index,
        uint256 slotIndex,
        string label
    );

    error ArrayOutOfBoundsUint256(
        uint256[] values,
        uint256 index,
        string label
    );

    error ArrayOutOfBoundsBytes(
        bytes[] values,
        uint256 index,
        string label
    );

    // WithdrawalStoreUtils errors
    error WithdrawalNotFound(bytes32 key);

    // WithdrawalUtils errors
    error EmptyWithdrawal();
    error EmptyWithdrawalAmount();
    error MinLongTokens(uint256 received, uint256 expected);
    error MinShortTokens(uint256 received, uint256 expected);
    error InsufficientMarketTokens(uint256 balance, uint256 expected);
    error InsufficientWntAmount(uint256 wntAmount, uint256 executionFee);
    error InvalidPoolValueForWithdrawal(int256 poolValue);

    // Uint256Mask errors
    error MaskIndexOutOfBounds(uint256 index, string label);
    error DuplicatedIndex(uint256 index, string label);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../role/RoleModule.sol";
import "./EventUtils.sol";

// @title EventEmitter
// @dev Contract to emit events
// This allows main events to be emitted from a single contract
// Logic contracts can be updated while re-using the same eventEmitter contract
// Peripheral services like monitoring or analytics would be able to continue
// to work without an update and without segregating historical data
contract EventEmitter is RoleModule {
    event EventLog(
        address msgSender,
        string eventName,
        string indexed eventNameHash,
        EventUtils.EventLogData eventData
    );

    event EventLog1(
        address msgSender,
        string eventName,
        string indexed eventNameHash,
        bytes32 indexed topic1,
        EventUtils.EventLogData eventData
    );

    event EventLog2(
        address msgSender,
        string eventName,
        string indexed eventNameHash,
        bytes32 indexed topic1,
        bytes32 indexed topic2,
        EventUtils.EventLogData eventData
    );

    constructor(RoleStore _roleStore) RoleModule(_roleStore) {}

    // @dev emit a general event log
    // @param eventName the name of the event
    // @param eventData the event data
    function emitEventLog(
        string memory eventName,
        EventUtils.EventLogData memory eventData
    ) external onlyController {
        emit EventLog(
            msg.sender,
            eventName,
            eventName,
            eventData
        );
    }

    // @dev emit a general event log
    // @param eventName the name of the event
    // @param topic1 topic1 for indexing
    // @param eventData the event data
    function emitEventLog1(
        string memory eventName,
        bytes32 topic1,
        EventUtils.EventLogData memory eventData
    ) external onlyController {
        emit EventLog1(
            msg.sender,
            eventName,
            eventName,
            topic1,
            eventData
        );
    }

    // @dev emit a general event log
    // @param eventName the name of the event
    // @param topic1 topic1 for indexing
    // @param topic2 topic2 for indexing
    // @param eventData the event data
    function emitEventLog2(
        string memory eventName,
        bytes32 topic1,
        bytes32 topic2,
        EventUtils.EventLogData memory eventData
    ) external onlyController {
        emit EventLog2(
            msg.sender,
            eventName,
            eventName,
            topic1,
            topic2,
            eventData
        );
    }
    // @dev event log for general use
    // @param topic1 event topic 1
    // @param data additional data
    function emitDataLog1(bytes32 topic1, bytes memory data) external onlyController {
        uint256 len = data.length;
        assembly {
            log1(add(data, 32), len, topic1)
        }
    }

    // @dev event log for general use
    // @param topic1 event topic 1
    // @param topic2 event topic 2
    // @param data additional data
    function emitDataLog2(bytes32 topic1, bytes32 topic2, bytes memory data) external onlyController {
        uint256 len = data.length;
        assembly {
            log2(add(data, 32), len, topic1, topic2)
        }
    }

    // @dev event log for general use
    // @param topic1 event topic 1
    // @param topic2 event topic 2
    // @param topic3 event topic 3
    // @param data additional data
    function emitDataLog3(bytes32 topic1, bytes32 topic2, bytes32 topic3, bytes memory data) external onlyController {
        uint256 len = data.length;
        assembly {
            log3(add(data, 32), len, topic1, topic2, topic3)
        }
    }

    // @dev event log for general use
    // @param topic1 event topic 1
    // @param topic2 event topic 2
    // @param topic3 event topic 3
    // @param topic4 event topic 4
    // @param data additional data
    function emitDataLog4(bytes32 topic1, bytes32 topic2, bytes32 topic3, bytes32 topic4, bytes memory data) external onlyController {
        uint256 len = data.length;
        assembly {
            log4(add(data, 32), len, topic1, topic2, topic3, topic4)
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library EventUtils {
    struct EmitPositionDecreaseParams {
        bytes32 key;
        address account;
        address market;
        address collateralToken;
        bool isLong;
    }

    struct EventLogData {
        AddressItems addressItems;
        UintItems uintItems;
        IntItems intItems;
        BoolItems boolItems;
        Bytes32Items bytes32Items;
        BytesItems bytesItems;
        StringItems stringItems;
    }

    struct AddressItems {
        AddressKeyValue[] items;
        AddressArrayKeyValue[] arrayItems;
    }

    struct UintItems {
        UintKeyValue[] items;
        UintArrayKeyValue[] arrayItems;
    }

    struct IntItems {
        IntKeyValue[] items;
        IntArrayKeyValue[] arrayItems;
    }

    struct BoolItems {
        BoolKeyValue[] items;
        BoolArrayKeyValue[] arrayItems;
    }

    struct Bytes32Items {
        Bytes32KeyValue[] items;
        Bytes32ArrayKeyValue[] arrayItems;
    }

    struct BytesItems {
        BytesKeyValue[] items;
        BytesArrayKeyValue[] arrayItems;
    }

    struct StringItems {
        StringKeyValue[] items;
        StringArrayKeyValue[] arrayItems;
    }

    struct AddressKeyValue {
        string key;
        address value;
    }

    struct AddressArrayKeyValue {
        string key;
        address[] value;
    }

    struct UintKeyValue {
        string key;
        uint256 value;
    }

    struct UintArrayKeyValue {
        string key;
        uint256[] value;
    }

    struct IntKeyValue {
        string key;
        int256 value;
    }

    struct IntArrayKeyValue {
        string key;
        int256[] value;
    }

    struct BoolKeyValue {
        string key;
        bool value;
    }

    struct BoolArrayKeyValue {
        string key;
        bool[] value;
    }

    struct Bytes32KeyValue {
        string key;
        bytes32 value;
    }

    struct Bytes32ArrayKeyValue {
        string key;
        bytes32[] value;
    }

    struct BytesKeyValue {
        string key;
        bytes value;
    }

    struct BytesArrayKeyValue {
        string key;
        bytes[] value;
    }

    struct StringKeyValue {
        string key;
        string value;
    }

    struct StringArrayKeyValue {
        string key;
        string[] value;
    }

    function initItems(AddressItems memory items, uint256 size) internal pure {
        items.items = new EventUtils.AddressKeyValue[](size);
    }

    function initArrayItems(AddressItems memory items, uint256 size) internal pure {
        items.arrayItems = new EventUtils.AddressArrayKeyValue[](size);
    }

    function setItem(AddressItems memory items, uint256 index, string memory key, address value) internal pure {
        items.items[index].key = key;
        items.items[index].value = value;
    }

    function setItem(AddressItems memory items, uint256 index, string memory key, address[] memory value) internal pure {
        items.arrayItems[index].key = key;
        items.arrayItems[index].value = value;
    }

    function initItems(UintItems memory items, uint256 size) internal pure {
        items.items = new EventUtils.UintKeyValue[](size);
    }

    function initArrayItems(UintItems memory items, uint256 size) internal pure {
        items.arrayItems = new EventUtils.UintArrayKeyValue[](size);
    }

    function setItem(UintItems memory items, uint256 index, string memory key, uint256 value) internal pure {
        items.items[index].key = key;
        items.items[index].value = value;
    }

    function setItem(UintItems memory items, uint256 index, string memory key, uint256[] memory value) internal pure {
        items.arrayItems[index].key = key;
        items.arrayItems[index].value = value;
    }

    function initItems(IntItems memory items, uint256 size) internal pure {
        items.items = new EventUtils.IntKeyValue[](size);
    }

    function initArrayItems(IntItems memory items, uint256 size) internal pure {
        items.arrayItems = new EventUtils.IntArrayKeyValue[](size);
    }

    function setItem(IntItems memory items, uint256 index, string memory key, int256 value) internal pure {
        items.items[index].key = key;
        items.items[index].value = value;
    }

    function setItem(IntItems memory items, uint256 index, string memory key, int256[] memory value) internal pure {
        items.arrayItems[index].key = key;
        items.arrayItems[index].value = value;
    }

    function initItems(BoolItems memory items, uint256 size) internal pure {
        items.items = new EventUtils.BoolKeyValue[](size);
    }

    function initArrayItems(BoolItems memory items, uint256 size) internal pure {
        items.arrayItems = new EventUtils.BoolArrayKeyValue[](size);
    }

    function setItem(BoolItems memory items, uint256 index, string memory key, bool value) internal pure {
        items.items[index].key = key;
        items.items[index].value = value;
    }

    function setItem(BoolItems memory items, uint256 index, string memory key, bool[] memory value) internal pure {
        items.arrayItems[index].key = key;
        items.arrayItems[index].value = value;
    }

    function initItems(Bytes32Items memory items, uint256 size) internal pure {
        items.items = new EventUtils.Bytes32KeyValue[](size);
    }

    function initArrayItems(Bytes32Items memory items, uint256 size) internal pure {
        items.arrayItems = new EventUtils.Bytes32ArrayKeyValue[](size);
    }

    function setItem(Bytes32Items memory items, uint256 index, string memory key, bytes32 value) internal pure {
        items.items[index].key = key;
        items.items[index].value = value;
    }

    function setItem(Bytes32Items memory items, uint256 index, string memory key, bytes32[] memory value) internal pure {
        items.arrayItems[index].key = key;
        items.arrayItems[index].value = value;
    }

    function initItems(BytesItems memory items, uint256 size) internal pure {
        items.items = new EventUtils.BytesKeyValue[](size);
    }

    function initArrayItems(BytesItems memory items, uint256 size) internal pure {
        items.arrayItems = new EventUtils.BytesArrayKeyValue[](size);
    }

    function setItem(BytesItems memory items, uint256 index, string memory key, bytes memory value) internal pure {
        items.items[index].key = key;
        items.items[index].value = value;
    }

    function setItem(BytesItems memory items, uint256 index, string memory key, bytes[] memory value) internal pure {
        items.arrayItems[index].key = key;
        items.arrayItems[index].value = value;
    }

    function initItems(StringItems memory items, uint256 size) internal pure {
        items.items = new EventUtils.StringKeyValue[](size);
    }

    function initArrayItems(StringItems memory items, uint256 size) internal pure {
        items.arrayItems = new EventUtils.StringArrayKeyValue[](size);
    }

    function setItem(StringItems memory items, uint256 index, string memory key, string memory value) internal pure {
        items.items[index].key = key;
        items.items[index].value = value;
    }

    function setItem(StringItems memory items, uint256 index, string memory key, string[] memory value) internal pure {
        items.arrayItems[index].key = key;
        items.arrayItems[index].value = value;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// @title IPriceFeed
// @dev Interface for a price feed
interface IPriceFeed {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../role/RoleModule.sol";

import "./OracleStore.sol";
import "./OracleUtils.sol";
import "./IPriceFeed.sol";
import "../price/Price.sol";

import "../chain/Chain.sol";
import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";

import "../utils/Bits.sol";
import "../utils/Array.sol";
import "../utils/Precision.sol";
import "../utils/Cast.sol";
import "../utils/Uint256Mask.sol";

// @title Oracle
// @dev Contract to validate and store signed values
// Some calculations e.g. calculating the size in tokens for a position
// may not work with zero / negative prices
// as a result, zero / negative prices are considered empty / invalid
// A market may need to be manually settled in this case
contract Oracle is RoleModule {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;
    using Price for Price.Props;
    using Uint256Mask for Uint256Mask.Mask;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    struct ValidatedPrice {
        address token;
        uint256 min;
        uint256 max;
        uint256 timestamp;
        uint256 minBlockNumber;
        uint256 maxBlockNumber;
    }

    // @dev SetPricesCache struct used in setPrices to avoid stack too deep errors
    // @param prevMinOracleBlockNumber the previous oracle block number of the loop
    // @param priceIndex the current price index to retrieve from compactedMinPrices and compactedMaxPrices
    // to construct the minPrices and maxPrices array
    // @param signatureIndex the current signature index to retrieve from the signatures array
    // @param maxPriceAge the max allowed age of price values
    // @param minPriceIndex the index of the min price in minPrices for the current signer
    // @param maxPriceIndex the index of the max price in maxPrices for the current signer
    // @param minPrices the min prices
    // @param maxPrices the max prices
    struct SetPricesCache {
        OracleUtils.ReportInfo info;
        uint256 minBlockConfirmations;
        uint256 maxPriceAge;
        uint256 maxRefPriceDeviationFactor;
        uint256 prevMinOracleBlockNumber;
        ValidatedPrice[] validatedPrices;
    }

    struct SetPricesInnerCache {
        uint256 priceIndex;
        uint256 signatureIndex;
        uint256 minPriceIndex;
        uint256 maxPriceIndex;
        uint256[] minPrices;
        uint256[] maxPrices;
        Uint256Mask.Mask minPriceIndexMask;
        Uint256Mask.Mask maxPriceIndexMask;
    }

    uint256 public constant SIGNER_INDEX_LENGTH = 16;
    // subtract 1 as the first slot is used to store number of signers
    uint256 public constant MAX_SIGNERS = 256 / SIGNER_INDEX_LENGTH - 1;
    // signer indexes are recorded in a signerIndexFlags uint256 value to check for uniqueness
    uint256 public constant MAX_SIGNER_INDEX = 256;

    OracleStore public oracleStore;

    // tokensWithPrices stores the tokens with prices that have been set
    // this is used in clearAllPrices to help ensure that all token prices
    // set in setPrices are cleared after use
    EnumerableSet.AddressSet internal tokensWithPrices;
    mapping(address => Price.Props) public primaryPrices;

    constructor(
        RoleStore _roleStore,
        OracleStore _oracleStore
    ) RoleModule(_roleStore) {
        oracleStore = _oracleStore;
    }

    // @dev validate and store signed prices
    //
    // The setPrices function is used to set the prices of tokens in the Oracle contract.
    // It accepts an array of tokens and a signerInfo parameter. The signerInfo parameter
    // contains information about the signers that have signed the transaction to set the prices.
    // The first 16 bits of the signerInfo parameter contain the number of signers, and the following
    // bits contain the index of each signer in the oracleStore. The function checks that the number
    // of signers is greater than or equal to the minimum number of signers required, and that
    // the signer indices are unique and within the maximum signer index. The function then calls
    // _setPrices and _setPricesFromPriceFeeds to set the prices of the tokens.
    //
    // Oracle prices are signed as a value together with a precision, this allows
    // prices to be compacted as uint32 values.
    //
    // The signed prices represent the price of one unit of the token using a value
    // with 30 decimals of precision.
    //
    // Representing the prices in this way allows for conversions between token amounts
    // and fiat values to be simplified, e.g. to calculate the fiat value of a given
    // number of tokens the calculation would just be: `token amount * oracle price`,
    // to calculate the token amount for a fiat value it would be: `fiat value / oracle price`.
    //
    // The trade-off of this simplicity in calculation is that tokens with a small USD
    // price and a lot of decimals may have precision issues it is also possible that
    // a token's price changes significantly and results in requiring higher precision.
    //
    // ## Example 1
    //
    // The price of ETH is 5000, and ETH has 18 decimals.
    //
    // The price of one unit of ETH is `5000 / (10 ^ 18), 5 * (10 ^ -15)`.
    //
    // To handle the decimals, multiply the value by `(10 ^ 30)`.
    //
    // Price would be stored as `5000 / (10 ^ 18) * (10 ^ 30) => 5000 * (10 ^ 12)`.
    //
    // For gas optimization, these prices are sent to the oracle in the form of a uint8
    // decimal multiplier value and uint32 price value.
    //
    // If the decimal multiplier value is set to 8, the uint32 value would be `5000 * (10 ^ 12) / (10 ^ 8) => 5000 * (10 ^ 4)`.
    //
    // With this config, ETH prices can have a maximum value of `(2 ^ 32) / (10 ^ 4) => 4,294,967,296 / (10 ^ 4) => 429,496.7296` with 4 decimals of precision.
    //
    // ## Example 2
    //
    // The price of BTC is 60,000, and BTC has 8 decimals.
    //
    // The price of one unit of BTC is `60,000 / (10 ^ 8), 6 * (10 ^ -4)`.
    //
    // Price would be stored as `60,000 / (10 ^ 8) * (10 ^ 30) => 6 * (10 ^ 26) => 60,000 * (10 ^ 22)`.
    //
    // BTC prices maximum value: `(2 ^ 32) / (10 ^ 2) => 4,294,967,296 / (10 ^ 2) => 42,949,672.96`.
    //
    // Decimals of precision: 2.
    //
    // ## Example 3
    //
    // The price of USDC is 1, and USDC has 6 decimals.
    //
    // The price of one unit of USDC is `1 / (10 ^ 6), 1 * (10 ^ -6)`.
    //
    // Price would be stored as `1 / (10 ^ 6) * (10 ^ 30) => 1 * (10 ^ 24)`.
    //
    // USDC prices maximum value: `(2 ^ 64) / (10 ^ 6) => 4,294,967,296 / (10 ^ 6) => 4294.967296`.
    //
    // Decimals of precision: 6.
    //
    // ## Example 4
    //
    // The price of DG is 0.00000001, and DG has 18 decimals.
    //
    // The price of one unit of DG is `0.00000001 / (10 ^ 18), 1 * (10 ^ -26)`.
    //
    // Price would be stored as `1 * (10 ^ -26) * (10 ^ 30) => 1 * (10 ^ 3)`.
    //
    // DG prices maximum value: `(2 ^ 64) / (10 ^ 11) => 4,294,967,296 / (10 ^ 11) => 0.04294967296`.
    //
    // Decimals of precision: 11.
    //
    // ## Decimal Multiplier
    //
    // The formula to calculate what the decimal multiplier value should be set to:
    //
    // Decimals: 30 - (token decimals) - (number of decimals desired for precision)
    //
    // - ETH: 30 - 18 - 4 => 8
    // - BTC: 30 - 8 - 2 => 20
    // - USDC: 30 - 6 - 6 => 18
    // - DG: 30 - 18 - 11 => 1
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param params OracleUtils.SetPricesParams
    function setPrices(
        DataStore dataStore,
        EventEmitter eventEmitter,
        OracleUtils.SetPricesParams memory params
    ) external onlyController {
        if (tokensWithPrices.length() != 0) {
            revert Errors.NonEmptyTokensWithPrices(tokensWithPrices.length());
        }

        _setPricesFromPriceFeeds(dataStore, eventEmitter, params.priceFeedTokens);

        // it is possible for transactions to be executed using just params.priceFeedTokens
        // in this case if params.tokens is empty, the function can return
        if (params.tokens.length == 0) { return; }

        _setPrices(
            dataStore,
            eventEmitter,
            params
        );
    }

    // @dev set the primary price
    // @param token the token to set the price for
    // @param price the price value to set to
    function setPrimaryPrice(address token, Price.Props memory price) external onlyController {
        _setPrimaryPrice(token, price);
    }

    // @dev clear all prices
    function clearAllPrices() external onlyController {
        uint256 length = tokensWithPrices.length();
        for (uint256 i; i < length; i++) {
            address token = tokensWithPrices.at(0);
            _removePrimaryPrice(token);
        }
    }

    // @dev get the length of tokensWithPrices
    // @return the length of tokensWithPrices
    function getTokensWithPricesCount() external view returns (uint256) {
        return tokensWithPrices.length();
    }

    // @dev get the tokens of tokensWithPrices for the specified indexes
    // @param start the start index, the value for this index will be included
    // @param end the end index, the value for this index will not be included
    // @return the tokens of tokensWithPrices for the specified indexes
    function getTokensWithPrices(uint256 start, uint256 end) external view returns (address[] memory) {
        return tokensWithPrices.valuesAt(start, end);
    }

    // @dev get the primary price of a token
    // @param token the token to get the price for
    // @return the primary price of a token
    function getPrimaryPrice(address token) external view returns (Price.Props memory) {
        if (token == address(0)) { return Price.Props(0, 0); }

        Price.Props memory price = primaryPrices[token];
        if (price.isEmpty()) {
            revert Errors.EmptyPrimaryPrice(token);
        }

        return price;
    }

    // @dev get the stable price of a token
    // @param dataStore DataStore
    // @param token the token to get the price for
    // @return the stable price of the token
    function getStablePrice(DataStore dataStore, address token) public view returns (uint256) {
        return dataStore.getUint(Keys.stablePriceKey(token));
    }

    // @dev get the multiplier value to convert the external price feed price to the price of 1 unit of the token
    // represented with 30 decimals
    // for example, if USDC has 6 decimals and a price of 1 USD, one unit of USDC would have a price of
    // 1 / (10 ^ 6) * (10 ^ 30) => 1 * (10 ^ 24)
    // if the external price feed has 8 decimals, the price feed price would be 1 * (10 ^ 8)
    // in this case the priceFeedMultiplier should be 10 ^ 46
    // the conversion of the price feed price would be 1 * (10 ^ 8) * (10 ^ 46) / (10 ^ 30) => 1 * (10 ^ 24)
    // formula for decimals for price feed multiplier: 60 - (external price feed decimals) - (token decimals)
    //
    // @param dataStore DataStore
    // @param token the token to get the price feed multiplier for
    // @return the price feed multipler
    function getPriceFeedMultiplier(DataStore dataStore, address token) public view returns (uint256) {
        uint256 multiplier = dataStore.getUint(Keys.priceFeedMultiplierKey(token));

        if (multiplier == 0) {
            revert Errors.EmptyPriceFeedMultiplier(token);
        }

        return multiplier;
    }

    function validatePrices(
        DataStore dataStore,
        OracleUtils.SetPricesParams memory params
    ) external view returns (ValidatedPrice[] memory) {
        return _validatePrices(dataStore, params);
    }

    // @dev validate and set prices
    // The _setPrices() function is a helper function that is called by the
    // setPrices() function. It takes in several parameters: a DataStore contract
    // instance, an EventEmitter contract instance, an array of signers, and an
    // OracleUtils.SetPricesParams struct containing information about the tokens
    // and their prices.
    // The function first initializes a SetPricesCache struct to store some temporary
    // values that will be used later in the function. It then loops through the array
    // of tokens and sets the corresponding values in the cache struct. For each token,
    // the function also loops through the array of signers and validates the signatures
    // for the min and max prices for that token. If the signatures are valid, the
    // function calculates the median min and max prices and sets them in the DataStore
    // contract.
    // Finally, the function emits an event to signal that the prices have been set.
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param signers the signers of the prices
    // @param params OracleUtils.SetPricesParams
    function _setPrices(
        DataStore dataStore,
        EventEmitter eventEmitter,
        OracleUtils.SetPricesParams memory params
    ) internal {
        ValidatedPrice[] memory validatedPrices = _validatePrices(dataStore, params);

        for (uint256 i = 0; i < validatedPrices.length; i++) {
            ValidatedPrice memory validatedPrice = validatedPrices[i];

            if (!primaryPrices[validatedPrice.token].isEmpty()) {
                revert Errors.DuplicateTokenPrice(validatedPrice.token);
            }

            emitOraclePriceUpdated(eventEmitter, validatedPrice.token, validatedPrice.min, validatedPrice.max, false);

            _setPrimaryPrice(validatedPrice.token, Price.Props(
                validatedPrice.min,
                validatedPrice.max
            ));
        }
    }

    function _validatePrices(
        DataStore dataStore,
        OracleUtils.SetPricesParams memory params
    ) internal view returns (ValidatedPrice[] memory) {
        address[] memory signers = _getSigners(dataStore, params);

        SetPricesCache memory cache;

        cache.validatedPrices = new ValidatedPrice[](params.tokens.length);
        cache.minBlockConfirmations = dataStore.getUint(Keys.MIN_ORACLE_BLOCK_CONFIRMATIONS);
        cache.maxPriceAge = dataStore.getUint(Keys.MAX_ORACLE_PRICE_AGE);
        cache.maxRefPriceDeviationFactor = dataStore.getUint(Keys.MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR);

        for (uint256 i; i < params.tokens.length; i++) {
            OracleUtils.ReportInfo memory reportInfo;
            SetPricesInnerCache memory innerCache;

            reportInfo.minOracleBlockNumber = OracleUtils.getUncompactedOracleBlockNumber(params.compactedMinOracleBlockNumbers, i);
            reportInfo.maxOracleBlockNumber = OracleUtils.getUncompactedOracleBlockNumber(params.compactedMaxOracleBlockNumbers, i);

            if (reportInfo.minOracleBlockNumber > reportInfo.maxOracleBlockNumber) {
                revert Errors.InvalidMinMaxBlockNumber(reportInfo.minOracleBlockNumber, reportInfo.maxOracleBlockNumber);
            }

            reportInfo.oracleTimestamp = OracleUtils.getUncompactedOracleTimestamp(params.compactedOracleTimestamps, i);

            if (reportInfo.minOracleBlockNumber > Chain.currentBlockNumber()) {
                revert Errors.InvalidBlockNumber(reportInfo.minOracleBlockNumber, Chain.currentBlockNumber());
            }

            if (reportInfo.oracleTimestamp + cache.maxPriceAge < Chain.currentTimestamp()) {
                revert Errors.MaxPriceAgeExceeded(reportInfo.oracleTimestamp, Chain.currentTimestamp());
            }

            // block numbers must be in ascending order
            if (reportInfo.minOracleBlockNumber < cache.prevMinOracleBlockNumber) {
                revert Errors.BlockNumbersNotSorted(reportInfo.minOracleBlockNumber, cache.prevMinOracleBlockNumber);
            }
            cache.prevMinOracleBlockNumber = reportInfo.minOracleBlockNumber;

            if (Chain.currentBlockNumber() - reportInfo.maxOracleBlockNumber <= cache.minBlockConfirmations) {
                reportInfo.blockHash = Chain.getBlockHash(reportInfo.maxOracleBlockNumber);
            }

            reportInfo.token = params.tokens[i];

            reportInfo.precision = 10 ** OracleUtils.getUncompactedDecimal(params.compactedDecimals, i);
            reportInfo.tokenOracleType = dataStore.getBytes32(Keys.oracleTypeKey(reportInfo.token));

            innerCache.minPrices = new uint256[](signers.length);
            innerCache.maxPrices = new uint256[](signers.length);

            for (uint256 j = 0; j < signers.length; j++) {
                innerCache.priceIndex = i * signers.length + j;
                innerCache.minPrices[j] = OracleUtils.getUncompactedPrice(params.compactedMinPrices, innerCache.priceIndex);
                innerCache.maxPrices[j] = OracleUtils.getUncompactedPrice(params.compactedMaxPrices, innerCache.priceIndex);

                if (j == 0) { continue; }

                // validate that minPrices are sorted in ascending order
                if (innerCache.minPrices[j - 1] > innerCache.minPrices[j]) {
                    revert Errors.MinPricesNotSorted(reportInfo.token, innerCache.minPrices[j], innerCache.minPrices[j - 1]);
                }

                // validate that maxPrices are sorted in ascending order
                if (innerCache.maxPrices[j - 1] > innerCache.maxPrices[j]) {
                    revert Errors.MaxPricesNotSorted(reportInfo.token, innerCache.maxPrices[j], innerCache.maxPrices[j - 1]);
                }
            }

            for (uint256 j = 0; j < signers.length; j++) {
                innerCache.signatureIndex = i * signers.length + j;
                innerCache.minPriceIndex = OracleUtils.getUncompactedPriceIndex(params.compactedMinPricesIndexes, innerCache.signatureIndex);
                innerCache.maxPriceIndex = OracleUtils.getUncompactedPriceIndex(params.compactedMaxPricesIndexes, innerCache.signatureIndex);

                if (innerCache.signatureIndex >= params.signatures.length) {
                    revert Errors.ArrayOutOfBoundsBytes(params.signatures, innerCache.signatureIndex, "signatures");
                }

                if (innerCache.minPriceIndex >= innerCache.minPrices.length) {
                    revert Errors.ArrayOutOfBoundsUint256(innerCache.minPrices, innerCache.minPriceIndex, "minPrices");
                }

                if (innerCache.maxPriceIndex >= innerCache.maxPrices.length) {
                    revert Errors.ArrayOutOfBoundsUint256(innerCache.maxPrices, innerCache.maxPriceIndex, "maxPrices");
                }

                // since minPrices, maxPrices have the same length as the signers array
                // and the signers array length is less than MAX_SIGNERS
                // minPriceIndexMask and maxPriceIndexMask should be able to store the indexes
                // using Uint256Mask
                innerCache.minPriceIndexMask.validateUniqueAndSetIndex(innerCache.minPriceIndex, "minPriceIndex");
                innerCache.maxPriceIndexMask.validateUniqueAndSetIndex(innerCache.maxPriceIndex, "maxPriceIndex");

                reportInfo.minPrice = innerCache.minPrices[innerCache.minPriceIndex];
                reportInfo.maxPrice = innerCache.maxPrices[innerCache.maxPriceIndex];

                if (reportInfo.minPrice > reportInfo.maxPrice) {
                    revert Errors.InvalidSignerMinMaxPrice(reportInfo.minPrice, reportInfo.maxPrice);
                }

                OracleUtils.validateSigner(
                    _getSalt(),
                    reportInfo,
                    params.signatures[innerCache.signatureIndex],
                    signers[j]
                );
            }

            uint256 medianMinPrice = Array.getMedian(innerCache.minPrices) * reportInfo.precision;
            uint256 medianMaxPrice = Array.getMedian(innerCache.maxPrices) * reportInfo.precision;

            (bool hasPriceFeed, uint256 refPrice) = _getPriceFeedPrice(dataStore, reportInfo.token);
            if (hasPriceFeed) {
                validateRefPrice(
                    reportInfo.token,
                    medianMinPrice,
                    refPrice,
                    cache.maxRefPriceDeviationFactor
                );

                validateRefPrice(
                    reportInfo.token,
                    medianMaxPrice,
                    refPrice,
                    cache.maxRefPriceDeviationFactor
                );
            }

            if (medianMinPrice == 0 || medianMaxPrice == 0) {
                revert Errors.InvalidOraclePrice(reportInfo.token);
            }

            if (medianMinPrice > medianMaxPrice) {
                revert Errors.InvalidMedianMinMaxPrice(medianMinPrice, medianMaxPrice);
            }

            cache.validatedPrices[i] = ValidatedPrice(
                reportInfo.token, // token
                medianMinPrice, // min
                medianMaxPrice, // max
                reportInfo.oracleTimestamp, // timestamp
                reportInfo.minOracleBlockNumber, // minBlockNumber
                reportInfo.maxOracleBlockNumber // maxBlockNumber
            );
        }

        return cache.validatedPrices;
    }

    function _getSigners(
        DataStore dataStore,
        OracleUtils.SetPricesParams memory params
    ) internal view returns (address[] memory) {
        // first 16 bits of signer info contains the number of signers
        address[] memory signers = new address[](params.signerInfo & Bits.BITMASK_16);

        if (signers.length < dataStore.getUint(Keys.MIN_ORACLE_SIGNERS)) {
            revert Errors.MinOracleSigners(signers.length, dataStore.getUint(Keys.MIN_ORACLE_SIGNERS));
        }

        if (signers.length > MAX_SIGNERS) {
            revert Errors.MaxOracleSigners(signers.length, MAX_SIGNERS);
        }

        Uint256Mask.Mask memory signerIndexMask;

        for (uint256 i; i < signers.length; i++) {
            uint256 signerIndex = params.signerInfo >> (16 + 16 * i) & Bits.BITMASK_16;

            if (signerIndex >= MAX_SIGNER_INDEX) {
                revert Errors.MaxSignerIndex(signerIndex, MAX_SIGNER_INDEX);
            }

            signerIndexMask.validateUniqueAndSetIndex(signerIndex, "signerIndex");

            signers[i] = oracleStore.getSigner(signerIndex);

            if (signers[i] == address(0)) {
                revert Errors.EmptySigner(signerIndex);
            }
        }

        return signers;
    }

    // it might be possible for the block.chainid to change due to a fork or similar
    // for this reason, this salt is not cached
    function _getSalt() internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, "xget-oracle-v1"));
    }

    function validateRefPrice(
        address token,
        uint256 price,
        uint256 refPrice,
        uint256 maxRefPriceDeviationFactor
    ) internal pure {
        uint256 diff = Calc.diff(price, refPrice);
        uint256 diffFactor = Precision.toFactor(diff, refPrice);

        if (diffFactor > maxRefPriceDeviationFactor) {
            revert Errors.MaxRefPriceDeviationExceeded(
                token,
                price,
                refPrice,
                maxRefPriceDeviationFactor
            );
        }
    }

    function _setPrimaryPrice(address token, Price.Props memory price) internal {
        primaryPrices[token] = price;
        tokensWithPrices.add(token);
    }

    function _removePrimaryPrice(address token) internal {
        delete primaryPrices[token];
        tokensWithPrices.remove(token);
    }

    // there is a small risk of stale pricing due to latency in price updates or if the chain is down
    // this is meant to be for temporary use until low latency price feeds are supported for all tokens
    function _getPriceFeedPrice(DataStore dataStore, address token) internal view returns (bool, uint256) {
        address priceFeedAddress = dataStore.getAddress(Keys.priceFeedKey(token));
        if (priceFeedAddress == address(0)) {
            return (false, 0);
        }

        IPriceFeed priceFeed = IPriceFeed(priceFeedAddress);

        (
            /* uint80 roundID */,
            int256 _price,
            /* uint256 startedAt */,
            uint256 timestamp,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();

        if (_price <= 0) {
            revert Errors.InvalidFeedPrice(token, _price);
        }

        uint256 heartbeatDuration = dataStore.getUint(Keys.priceFeedHeartbeatDurationKey(token));
        if (Chain.currentTimestamp() > timestamp && Chain.currentTimestamp() - timestamp > heartbeatDuration) {
            revert Errors.PriceFeedNotUpdated(token, timestamp, heartbeatDuration);
        }

        uint256 price = SafeCast.toUint256(_price);
        uint256 precision = getPriceFeedMultiplier(dataStore, token);

        uint256 adjustedPrice = Precision.mulDiv(price, precision, Precision.FLOAT_PRECISION);

        return (true, adjustedPrice);
    }

    // @dev set prices using external price feeds to save costs for tokens with stable prices
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param priceFeedTokens the tokens to set the prices using the price feeds for
    function _setPricesFromPriceFeeds(DataStore dataStore, EventEmitter eventEmitter, address[] memory priceFeedTokens) internal {
        for (uint256 i; i < priceFeedTokens.length; i++) {
            address token = priceFeedTokens[i];

            if (!primaryPrices[token].isEmpty()) {
                revert Errors.PriceAlreadySet(token, primaryPrices[token].min, primaryPrices[token].max);
            }

            (bool hasPriceFeed, uint256 price) = _getPriceFeedPrice(dataStore, token);

            if (!hasPriceFeed) {
                revert Errors.EmptyPriceFeed(token);
            }

            uint256 stablePrice = getStablePrice(dataStore, token);

            Price.Props memory priceProps;

            if (stablePrice > 0) {
                priceProps = Price.Props(
                    price < stablePrice ? price : stablePrice,
                    price < stablePrice ? stablePrice : price
                );
            } else {
                priceProps = Price.Props(
                    price,
                    price
                );
            }

            _setPrimaryPrice(token, priceProps);

            emitOraclePriceUpdated(eventEmitter, token, priceProps.min, priceProps.max, true);
        }
    }

    function emitOraclePriceUpdated(
        EventEmitter eventEmitter,
        address token,
        uint256 minPrice,
        uint256 maxPrice,
        bool isPriceFeed
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "token", token);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "minPrice", minPrice);
        eventData.uintItems.setItem(1, "maxPrice", maxPrice);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isPriceFeed", isPriceFeed);

        eventEmitter.emitEventLog1(
            "OraclePriceUpdate",
            Cast.toBytes32(token),
            eventData
        );
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../role/RoleModule.sol";
import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";
import "../utils/Cast.sol";

// @title OracleStore
// @dev Stores the list of oracle signers
contract OracleStore is RoleModule {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.AddressSet;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    EventEmitter public immutable eventEmitter;

    EnumerableSet.AddressSet internal signers;

    constructor(RoleStore _roleStore, EventEmitter _eventEmitter) RoleModule(_roleStore) {
        eventEmitter = _eventEmitter;
    }

    // @dev adds a signer
    // @param account address of the signer to add
    function addSigner(address account) external onlyController {
        signers.add(account);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventEmitter.emitEventLog1(
            "SignerAdded",
            Cast.toBytes32(account),
            eventData
        );
    }

    // @dev removes a signer
    // @param account address of the signer to remove
    function removeSigner(address account) external onlyController {
        signers.remove(account);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventEmitter.emitEventLog1(
            "SignerRemoved",
            Cast.toBytes32(account),
            eventData
        );
    }

    // @dev get the total number of signers
    // @return the total number of signers
    function getSignerCount() external view returns (uint256) {
        return signers.length();
    }

    // @dev get the signer at the specified index
    // @param index the index of the signer to get
    // @return the signer at the specified index
    function getSigner(uint256 index) external view returns (address) {
        return signers.at(index);
    }

    // @dev get the signers for the specified indexes
    // @param start the start index, the value for this index will be included
    // @param end the end index, the value for this index will not be included
    // @return the signers for the specified indexes
    function getSigners(uint256 start, uint256 end) external view returns (address[] memory) {
        return signers.valuesAt(start, end);
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../utils/Array.sol";
import "../utils/Bits.sol";
import "../price/Price.sol";
import "../utils/Printer.sol";

// @title OracleUtils
// @dev Library for oracle functions
library OracleUtils {
    using Array for uint256[];

    // @dev SetPricesParams struct for values required in Oracle.setPrices
    // @param signerInfo compacted indexes of signers, the index is used to retrieve
    // the signer address from the OracleStore
    // @param tokens list of tokens to set prices for
    // @param compactedOracleBlockNumbers compacted oracle block numbers
    // @param compactedOracleTimestamps compacted oracle timestamps
    // @param compactedDecimals compacted decimals for prices
    // @param compactedMinPrices compacted min prices
    // @param compactedMinPricesIndexes compacted min price indexes
    // @param compactedMaxPrices compacted max prices
    // @param compactedMaxPricesIndexes compacted max price indexes
    // @param signatures signatures of the oracle signers
    // @param priceFeedTokens tokens to set prices for based on an external price feed value
    struct SetPricesParams {
        uint256 signerInfo;
        address[] tokens;
        uint256[] compactedMinOracleBlockNumbers;
        uint256[] compactedMaxOracleBlockNumbers;
        uint256[] compactedOracleTimestamps;
        uint256[] compactedDecimals;
        uint256[] compactedMinPrices;
        uint256[] compactedMinPricesIndexes;
        uint256[] compactedMaxPrices;
        uint256[] compactedMaxPricesIndexes;
        bytes[] signatures;
        address[] priceFeedTokens;
    }

    struct SimulatePricesParams {
        address[] primaryTokens;
        Price.Props[] primaryPrices;
    }

    struct ReportInfo {
        uint256 minOracleBlockNumber;
        uint256 maxOracleBlockNumber;
        uint256 oracleTimestamp;
        bytes32 blockHash;
        address token;
        bytes32 tokenOracleType;
        uint256 precision;
        uint256 minPrice;
        uint256 maxPrice;
    }

    // compacted prices have a length of 32 bits
    uint256 public constant COMPACTED_PRICE_BIT_LENGTH = 32;
    uint256 public constant COMPACTED_PRICE_BITMASK = Bits.BITMASK_32;

    // compacted precisions have a length of 8 bits
    uint256 public constant COMPACTED_PRECISION_BIT_LENGTH = 8;
    uint256 public constant COMPACTED_PRECISION_BITMASK = Bits.BITMASK_8;

    // compacted block numbers have a length of 64 bits
    uint256 public constant COMPACTED_BLOCK_NUMBER_BIT_LENGTH = 64;
    uint256 public constant COMPACTED_BLOCK_NUMBER_BITMASK = Bits.BITMASK_64;

    // compacted timestamps have a length of 64 bits
    uint256 public constant COMPACTED_TIMESTAMP_BIT_LENGTH = 64;
    uint256 public constant COMPACTED_TIMESTAMP_BITMASK = Bits.BITMASK_64;

    // compacted price indexes have a length of 8 bits
    uint256 public constant COMPACTED_PRICE_INDEX_BIT_LENGTH = 8;
    uint256 public constant COMPACTED_PRICE_INDEX_BITMASK = Bits.BITMASK_8;

    function validateBlockNumberWithinRange(
        uint256[] memory minOracleBlockNumbers,
        uint256[] memory maxOracleBlockNumbers,
        uint256 blockNumber
    ) internal pure {
        if (!isBlockNumberWithinRange(
                minOracleBlockNumbers,
                maxOracleBlockNumbers,
                blockNumber
        )) {
            revert Errors.OracleBlockNumberNotWithinRange(
                minOracleBlockNumbers,
                maxOracleBlockNumbers,
                blockNumber
            );
        }
    }

    function isBlockNumberWithinRange(
        uint256[] memory minOracleBlockNumbers,
        uint256[] memory maxOracleBlockNumbers,
        uint256 blockNumber
    ) internal pure returns (bool) {
        if (!minOracleBlockNumbers.areLessThanOrEqualTo(blockNumber)) {
            return false;
        }

        if (!maxOracleBlockNumbers.areGreaterThanOrEqualTo(blockNumber)) {
            return false;
        }

        return true;
    }

    // @dev get the uncompacted price at the specified index
    // @param compactedPrices the compacted prices
    // @param index the index to get the uncompacted price at
    // @return the uncompacted price at the specified index
    function getUncompactedPrice(uint256[] memory compactedPrices, uint256 index) internal pure returns (uint256) {
        uint256 price = Array.getUncompactedValue(
            compactedPrices,
            index,
            COMPACTED_PRICE_BIT_LENGTH,
            COMPACTED_PRICE_BITMASK,
            "getUncompactedPrice"
        );

        if (price == 0) { revert Errors.EmptyCompactedPrice(index); }

        return price;
    }

    // @dev get the uncompacted decimal at the specified index
    // @param compactedDecimals the compacted decimals
    // @param index the index to get the uncompacted decimal at
    // @return the uncompacted decimal at the specified index
    function getUncompactedDecimal(uint256[] memory compactedDecimals, uint256 index) internal pure returns (uint256) {
        uint256 decimal = Array.getUncompactedValue(
            compactedDecimals,
            index,
            COMPACTED_PRECISION_BIT_LENGTH,
            COMPACTED_PRECISION_BITMASK,
            "getUncompactedDecimal"
        );

        return decimal;
    }


    // @dev get the uncompacted price index at the specified index
    // @param compactedPriceIndexes the compacted indexes
    // @param index the index to get the uncompacted price index at
    // @return the uncompacted price index at the specified index
    function getUncompactedPriceIndex(uint256[] memory compactedPriceIndexes, uint256 index) internal pure returns (uint256) {
        uint256 priceIndex = Array.getUncompactedValue(
            compactedPriceIndexes,
            index,
            COMPACTED_PRICE_INDEX_BIT_LENGTH,
            COMPACTED_PRICE_INDEX_BITMASK,
            "getUncompactedPriceIndex"
        );

        return priceIndex;

    }

    // @dev get the uncompacted oracle block numbers
    // @param compactedOracleBlockNumbers the compacted oracle block numbers
    // @param length the length of the uncompacted oracle block numbers
    // @return the uncompacted oracle block numbers
    function getUncompactedOracleBlockNumbers(uint256[] memory compactedOracleBlockNumbers, uint256 length) internal pure returns (uint256[] memory) {
        uint256[] memory blockNumbers = new uint256[](length);

        for (uint256 i; i < length; i++) {
            blockNumbers[i] = getUncompactedOracleBlockNumber(compactedOracleBlockNumbers, i);
        }

        return blockNumbers;
    }

    // @dev get the uncompacted oracle block number
    // @param compactedOracleBlockNumbers the compacted oracle block numbers
    // @param index the index to get the uncompacted oracle block number at
    // @return the uncompacted oracle block number
    function getUncompactedOracleBlockNumber(uint256[] memory compactedOracleBlockNumbers, uint256 index) internal pure returns (uint256) {
        uint256 blockNumber = Array.getUncompactedValue(
            compactedOracleBlockNumbers,
            index,
            COMPACTED_BLOCK_NUMBER_BIT_LENGTH,
            COMPACTED_BLOCK_NUMBER_BITMASK,
            "getUncompactedOracleBlockNumber"
        );

        if (blockNumber == 0) { revert Errors.EmptyCompactedBlockNumber(index); }

        return blockNumber;
    }

    // @dev get the uncompacted oracle timestamp
    // @param compactedOracleTimestamps the compacted oracle timestamps
    // @param index the index to get the uncompacted oracle timestamp at
    // @return the uncompacted oracle timestamp
    function getUncompactedOracleTimestamp(uint256[] memory compactedOracleTimestamps, uint256 index) internal pure returns (uint256) {
        uint256 timestamp = Array.getUncompactedValue(
            compactedOracleTimestamps,
            index,
            COMPACTED_TIMESTAMP_BIT_LENGTH,
            COMPACTED_TIMESTAMP_BITMASK,
            "getUncompactedOracleTimestamp"
        );

        if (timestamp == 0) { revert Errors.EmptyCompactedTimestamp(index); }

        return timestamp;
    }

    // @dev validate the signer of a price
    // before calling this function, the expectedSigner should be validated to
    // ensure that it is not the zero address
    // @param minOracleBlockNumber the min block number used for the signed message hash
    // @param maxOracleBlockNumber the max block number used for the signed message hash
    // @param oracleTimestamp the timestamp used for the signed message hash
    // @param blockHash the block hash used for the signed message hash
    // @param token the token used for the signed message hash
    // @param precision the precision used for the signed message hash
    // @param minPrice the min price used for the signed message hash
    // @param maxPrice the max price used for the signed message hash
    // @param signature the signer's signature
    // @param expectedSigner the address of the expected signer
    function validateSigner(
        bytes32 salt,
        ReportInfo memory info,
        bytes memory signature,
        address expectedSigner
    ) internal pure {
        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encode(
                salt,
                info.minOracleBlockNumber,
                info.maxOracleBlockNumber,
                info.oracleTimestamp,
                info.blockHash,
                info.token,
                info.tokenOracleType,
                info.precision,
                info.minPrice,
                info.maxPrice
            ))
        );

        address recoveredSigner = ECDSA.recover(digest, signature);
        if (recoveredSigner != expectedSigner) {
            revert Errors.InvalidSignature(recoveredSigner, expectedSigner);
        }
    }

    function revertOracleBlockNumberNotWithinRange(
        uint256[] memory minOracleBlockNumbers,
        uint256[] memory maxOracleBlockNumbers,
        uint256 blockNumber
    ) internal pure {
        revert Errors.OracleBlockNumberNotWithinRange(minOracleBlockNumbers, maxOracleBlockNumbers, blockNumber);
    }

    function isOracleError(bytes4 errorSelector) internal pure returns (bool) {
        if (isOracleBlockNumberError(errorSelector)) {
            return true;
        }

        if (isEmptyPriceError(errorSelector)) {
            return true;
        }

        return false;
    }

    function isEmptyPriceError(bytes4 errorSelector) internal pure returns (bool) {
        if (errorSelector == Errors.EmptyPrimaryPrice.selector) {
            return true;
        }

        return false;
    }

    function isOracleBlockNumberError(bytes4 errorSelector) internal pure returns (bool) {
        if (errorSelector == Errors.OracleBlockNumbersAreSmallerThanRequired.selector) {
            return true;
        }

        if (errorSelector == Errors.OracleBlockNumberNotWithinRange.selector) {
            return true;
        }

        return false;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// @title Price
// @dev Struct for prices
library Price {
    // @param min the min price
    // @param max the max price
    struct Props {
        uint256 min;
        uint256 max;
    }

    // @dev check if a price is empty
    // @param props Props
    // @return whether a price is empty
    function isEmpty(Props memory props) internal pure returns (bool) {
        return props.min == 0 || props.max == 0;
    }

    // @dev get the average of the min and max values
    // @param props Props
    // @return the average of the min and max values
    function midPrice(Props memory props) internal pure returns (uint256) {
        return (props.max + props.min) / 2;
    }

    // @dev pick either the min or max value
    // @param props Props
    // @param maximize whether to pick the min or max value
    // @return either the min or max value
    function pickPrice(Props memory props, bool maximize) internal pure returns (uint256) {
        return maximize ? props.max : props.min;
    }

    // @dev pick the min or max price depending on whether it is for a long or short position
    // and whether the pending pnl should be maximized or not
    // @param props Props
    // @param isLong whether it is for a long or short position
    // @param maximize whether the pnl should be maximized or not
    // @return the min or max price
    function pickPriceForPnl(Props memory props, bool isLong, bool maximize) internal pure returns (uint256) {
        // for long positions, pick the larger price to maximize pnl
        // for short positions, pick the smaller price to maximize pnl
        if (isLong) {
            return maximize ? props.max : props.min;
        }

        return maximize ? props.min : props.max;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title Role
 * @dev Library for role keys
 */
library Role {
    /**
     * @dev The ROLE_ADMIN role.
     */
    bytes32 public constant ROLE_ADMIN = keccak256(abi.encode("ROLE_ADMIN"));

    /**
     * @dev The TIMELOCK_ADMIN role.
     */
    bytes32 public constant TIMELOCK_ADMIN = keccak256(abi.encode("TIMELOCK_ADMIN"));

    /**
     * @dev The TIMELOCK_MULTISIG role.
     */
    bytes32 public constant TIMELOCK_MULTISIG = keccak256(abi.encode("TIMELOCK_MULTISIG"));

    /**
     * @dev The CONFIG_KEEPER role.
     */
    bytes32 public constant CONFIG_KEEPER = keccak256(abi.encode("CONFIG_KEEPER"));

    /**
     * @dev The CONTROLLER role.
     */
    bytes32 public constant CONTROLLER = keccak256(abi.encode("CONTROLLER"));

    /**
     * @dev The ROUTER_PLUGIN role.
     */
    bytes32 public constant ROUTER_PLUGIN = keccak256(abi.encode("ROUTER_PLUGIN"));

    /**
     * @dev The MARKET_KEEPER role.
     */
    bytes32 public constant MARKET_KEEPER = keccak256(abi.encode("MARKET_KEEPER"));

    /**
     * @dev The FEE_KEEPER role.
     */
    bytes32 public constant FEE_KEEPER = keccak256(abi.encode("FEE_KEEPER"));

    /**
     * @dev The ORDER_KEEPER role.
     */
    bytes32 public constant ORDER_KEEPER = keccak256(abi.encode("ORDER_KEEPER"));

    /**
     * @dev The FROZEN_ORDER_KEEPER role.
     */
    bytes32 public constant FROZEN_ORDER_KEEPER = keccak256(abi.encode("FROZEN_ORDER_KEEPER"));

    /**
     * @dev The PRICING_KEEPER role.
     */
    bytes32 public constant PRICING_KEEPER = keccak256(abi.encode("PRICING_KEEPER"));
    /**
     * @dev The LIQUIDATION_KEEPER role.
     */
    bytes32 public constant LIQUIDATION_KEEPER = keccak256(abi.encode("LIQUIDATION_KEEPER"));
    /**
     * @dev The ADL_KEEPER role.
     */
    bytes32 public constant ADL_KEEPER = keccak256(abi.encode("ADL_KEEPER"));
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./RoleStore.sol";

/**
 * @title RoleModule
 * @dev Contract for role validation functions
 */
contract RoleModule {
    RoleStore public immutable roleStore;

    /**
     * @dev Constructor that initializes the role store for this contract.
     *
     * @param _roleStore The contract instance to use as the role store.
     */
    constructor(RoleStore _roleStore) {
        roleStore = _roleStore;
    }

    /**
     * @dev Only allows the contract's own address to call the function.
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert Errors.Unauthorized(msg.sender, "SELF");
        }
        _;
    }

    /**
     * @dev Only allows addresses with the TIMELOCK_MULTISIG role to call the function.
     */
    modifier onlyTimelockMultisig() {
        _validateRole(Role.TIMELOCK_MULTISIG, "TIMELOCK_MULTISIG");
        _;
    }

    /**
     * @dev Only allows addresses with the TIMELOCK_ADMIN role to call the function.
     */
    modifier onlyTimelockAdmin() {
        _validateRole(Role.TIMELOCK_ADMIN, "TIMELOCK_ADMIN");
        _;
    }

    /**
     * @dev Only allows addresses with the CONFIG_KEEPER role to call the function.
     */
    modifier onlyConfigKeeper() {
        _validateRole(Role.CONFIG_KEEPER, "CONFIG_KEEPER");
        _;
    }

    /**
     * @dev Only allows addresses with the CONTROLLER role to call the function.
     */
    modifier onlyController() {
        _validateRole(Role.CONTROLLER, "CONTROLLER");
        _;
    }

    /**
     * @dev Only allows addresses with the ROUTER_PLUGIN role to call the function.
     */
    modifier onlyRouterPlugin() {
        _validateRole(Role.ROUTER_PLUGIN, "ROUTER_PLUGIN");
        _;
    }

    /**
     * @dev Only allows addresses with the MARKET_KEEPER role to call the function.
     */
    modifier onlyMarketKeeper() {
        _validateRole(Role.MARKET_KEEPER, "MARKET_KEEPER");
        _;
    }

    /**
     * @dev Only allows addresses with the FEE_KEEPER role to call the function.
     */
    modifier onlyFeeKeeper() {
        _validateRole(Role.FEE_KEEPER, "FEE_KEEPER");
        _;
    }

    /**
     * @dev Only allows addresses with the ORDER_KEEPER role to call the function.
     */
    modifier onlyOrderKeeper() {
        _validateRole(Role.ORDER_KEEPER, "ORDER_KEEPER");
        _;
    }

    /**
     * @dev Only allows addresses with the PRICING_KEEPER role to call the function.
     */
    modifier onlyPricingKeeper() {
        _validateRole(Role.PRICING_KEEPER, "PRICING_KEEPER");
        _;
    }

    /**
     * @dev Only allows addresses with the LIQUIDATION_KEEPER role to call the function.
     */
    modifier onlyLiquidationKeeper() {
        _validateRole(Role.LIQUIDATION_KEEPER, "LIQUIDATION_KEEPER");
        _;
    }

    /**
     * @dev Only allows addresses with the ADL_KEEPER role to call the function.
     */
    modifier onlyAdlKeeper() {
        _validateRole(Role.ADL_KEEPER, "ADL_KEEPER");
        _;
    }

    /**
     * @dev Validates that the caller has the specified role.
     *
     * If the caller does not have the specified role, the transaction is reverted.
     *
     * @param role The key of the role to validate.
     * @param roleName The name of the role to validate.
     */
    function _validateRole(bytes32 role, string memory roleName) internal view {
        if (!roleStore.hasRole(msg.sender, role)) {
            revert Errors.Unauthorized(msg.sender, roleName);
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/EnumerableValues.sol";
import "./Role.sol";
import "../error/Errors.sol";

/**
 * @title RoleStore
 * @dev Stores roles and their members.
 */
contract RoleStore {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableValues for EnumerableSet.AddressSet;
    using EnumerableValues for EnumerableSet.Bytes32Set;

    EnumerableSet.Bytes32Set internal roles;
    mapping(bytes32 => EnumerableSet.AddressSet) internal roleMembers;
    // checking if an account has a role is a frequently used function
    // roleCache helps to save gas by offering a more efficient lookup
    // vs calling roleMembers[key].contains(account)
    mapping(address => mapping (bytes32 => bool)) roleCache;

    modifier onlyRoleAdmin() {
        if (!hasRole(msg.sender, Role.ROLE_ADMIN)) {
            revert Errors.Unauthorized(msg.sender, "ROLE_ADMIN");
        }
        _;
    }

    constructor() {
        _grantRole(msg.sender, Role.ROLE_ADMIN);
    }

    /**
     * @dev Grants the specified role to the given account.
     *
     * @param account The address of the account.
     * @param roleKey The key of the role to grant.
     */
    function grantRole(address account, bytes32 roleKey) external onlyRoleAdmin {
        _grantRole(account, roleKey);
    }

    /**
     * @dev Revokes the specified role from the given account.
     *
     * @param account The address of the account.
     * @param roleKey The key of the role to revoke.
     */
    function revokeRole(address account, bytes32 roleKey) external onlyRoleAdmin {
        _revokeRole(account, roleKey);
    }

    /**
     * @dev Returns true if the given account has the specified role.
     *
     * @param account The address of the account.
     * @param roleKey The key of the role.
     * @return True if the account has the role, false otherwise.
     */
    function hasRole(address account, bytes32 roleKey) public view returns (bool) {
        return roleCache[account][roleKey];
    }

    /**
     * @dev Returns the number of roles stored in the contract.
     *
     * @return The number of roles.
     */
    function getRoleCount() external view returns (uint256) {
        return roles.length();
    }

    /**
     * @dev Returns the keys of the roles stored in the contract.
     *
     * @param start The starting index of the range of roles to return.
     * @param end The ending index of the range of roles to return.
     * @return The keys of the roles.
     */
    function getRoles(uint256 start, uint256 end) external view returns (bytes32[] memory) {
        return roles.valuesAt(start, end);
    }

    /**
     * @dev Returns the number of members of the specified role.
     *
     * @param roleKey The key of the role.
     * @return The number of members of the role.
     */
    function getRoleMemberCount(bytes32 roleKey) external view returns (uint256) {
        return roleMembers[roleKey].length();
    }

    /**
     * @dev Returns the members of the specified role.
     *
     * @param roleKey The key of the role.
     * @param start the start index, the value for this index will be included.
     * @param end the end index, the value for this index will not be included.
     * @return The members of the role.
     */
    function getRoleMembers(bytes32 roleKey, uint256 start, uint256 end) external view returns (address[] memory) {
        return roleMembers[roleKey].valuesAt(start, end);
    }

    function _grantRole(address account, bytes32 roleKey) internal {
        roles.add(roleKey);
        roleMembers[roleKey].add(account);
        roleCache[account][roleKey] = true;
    }

    function _revokeRole(address account, bytes32 roleKey) internal {
        roleMembers[roleKey].remove(account);
        roleCache[account][roleKey] = false;

        if (roleMembers[roleKey].length() == 0) {
            if (roleKey == Role.ROLE_ADMIN) {
                revert Errors.ThereMustBeAtLeastOneRoleAdmin();
            }
            if (roleKey == Role.TIMELOCK_MULTISIG) {
                revert Errors.ThereMustBeAtLeastOneTimelockMultiSig();
            }
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../error/Errors.sol";

/**
 * @title Array
 * @dev Library for array functions
 */
library Array {
    using SafeCast for int256;

    /**
     * @dev Gets the value of the element at the specified index in the given array. If the index is out of bounds, returns 0.
     *
     * @param arr the array to get the value from
     * @param index the index of the element in the array
     * @return the value of the element at the specified index in the array
     */
    function get(bytes32[] memory arr, uint256 index) internal pure returns (bytes32) {
        if (index < arr.length) {
            return arr[index];
        }

        return bytes32(0);
    }

    /**
     * @dev Determines whether all of the elements in the given array are equal to the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are equal to the specified value, false otherwise
     */
    function areEqualTo(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] != value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are greater than the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are greater than the specified value, false otherwise
     */
    function areGreaterThan(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] <= value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are greater than or equal to the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are greater than or equal to the specified value, false otherwise
     */
    function areGreaterThanOrEqualTo(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] < value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are less than the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are less than the specified value, false otherwise
     */
    function areLessThan(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] >= value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are less than or equal to the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are less than or equal to the specified value, false otherwise
     */
    function areLessThanOrEqualTo(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] > value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Gets the median value of the elements in the given array. For arrays with an odd number of elements, returns the element at the middle index. For arrays with an even number of elements, returns the average of the two middle elements.
     *
     * @param arr the array to get the median value from
     * @return the median value of the elements in the given array
     */
    function getMedian(uint256[] memory arr) internal pure returns (uint256) {
        if (arr.length % 2 == 1) {
            return arr[arr.length / 2];
        }

        return (arr[arr.length / 2] + arr[arr.length / 2 - 1]) / 2;
    }

    /**
     * @dev Gets the uncompacted value at the specified index in the given array of compacted values.
     *
     * @param compactedValues the array of compacted values to get the uncompacted value from
     * @param index the index of the uncompacted value in the array
     * @param compactedValueBitLength the length of each compacted value, in bits
     * @param bitmask the bitmask to use to extract the uncompacted value from the compacted value
     * @return the uncompacted value at the specified index in the array of compacted values
     */
    function getUncompactedValue(
        uint256[] memory compactedValues,
        uint256 index,
        uint256 compactedValueBitLength,
        uint256 bitmask,
        string memory label
    ) internal pure returns (uint256) {
        uint256 compactedValuesPerSlot = 256 / compactedValueBitLength;

        uint256 slotIndex = index / compactedValuesPerSlot;
        if (slotIndex >= compactedValues.length) {
            revert Errors.CompactedArrayOutOfBounds(compactedValues, index, slotIndex, label);
        }

        uint256 slotBits = compactedValues[slotIndex];
        uint256 offset = (index - slotIndex * compactedValuesPerSlot) * compactedValueBitLength;

        uint256 value = (slotBits >> offset) & bitmask;

        return value;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title Bits
 * @dev Library for bit values
 */
library Bits {
    // @dev uint256(~0) is 256 bits of 1s
    // @dev shift the 1s by (256 - 8) to get (256 - 8) 0s followed by 8 1s
    uint256 constant public BITMASK_8 = ~uint256(0) >> (256 - 8);
    // @dev shift the 1s by (256 - 16) to get (256 - 16) 0s followed by 16 1s
    uint256 constant public BITMASK_16 = ~uint256(0) >> (256 - 16);
    // @dev shift the 1s by (256 - 32) to get (256 - 32) 0s followed by 32 1s
    uint256 constant public BITMASK_32 = ~uint256(0) >> (256 - 32);
    // @dev shift the 1s by (256 - 64) to get (256 - 64) 0s followed by 64 1s
    uint256 constant public BITMASK_64 = ~uint256(0) >> (256 - 64);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title Calc
 * @dev Library for math functions
 */
library Calc {
    using SignedMath for int256;
    using SafeCast for uint256;

    /**
     * @dev Calculates the result of dividing the first number by the second number,
     * rounded up to the nearest integer.
     *
     * @param a the dividend
     * @param b the divisor
     * @return the result of dividing the first number by the second number, rounded up to the nearest integer
     */
    function roundUpDivision(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a + b - 1) / b;
    }

    /**
     * Calculates the result of dividing the first number by the second number,
     * rounded up to the nearest integer.
     * The rounding is purely on the magnitude of a, if a is negative the result
     * is a larger magnitude negative
     *
     * @param a the dividend
     * @param b the divisor
     * @return the result of dividing the first number by the second number, rounded up to the nearest integer
     */
    function roundUpMagnitudeDivision(int256 a, uint256 b) internal pure returns (int256) {
        if (a < 0) {
            return (a - b.toInt256() + 1) / b.toInt256();
        }

        return (a + b.toInt256() - 1) / b.toInt256();
    }

    /**
     * Adds two numbers together and return a uint256 value, treating the second number as a signed integer.
     *
     * @param a the first number
     * @param b the second number
     * @return the result of adding the two numbers together
     */
    function sumReturnUint256(uint256 a, int256 b) internal pure returns (uint256) {
        if (b > 0) {
            return a + b.abs();
        }

        return a - b.abs();
    }

    /**
     * Adds two numbers together and return an int256 value, treating the second number as a signed integer.
     *
     * @param a the first number
     * @param b the second number
     * @return the result of adding the two numbers together
     */
    function sumReturnInt256(uint256 a, int256 b) internal pure returns (int256) {
        return a.toInt256() + b;
    }

    /**
     * @dev Calculates the absolute difference between two numbers.
     *
     * @param a the first number
     * @param b the second number
     * @return the absolute difference between the two numbers
     */
    function diff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /**
     * Adds two numbers together, the result is bounded to prevent overflows.
     *
     * @param a the first number
     * @param b the second number
     * @return the result of adding the two numbers together
     */
    function boundedAdd(int256 a, int256 b) internal pure returns (int256) {
        // if either a or b is zero or if the signs are different there should not be any overflows
        if (a == 0 || b == 0 || (a < 0 && b > 0) || (a > 0 && b < 0)) {
            return a + b;
        }

        // if adding `b` to `a` would result in a value less than the min int256 value
        // then return the min int256 value
        if (a < 0 && b <= type(int256).min - a) {
            return type(int256).min;
        }

        // if adding `b` to `a` would result in a value more than the max int256 value
        // then return the max int256 value
        if (a > 0 && b >= type(int256).max - a) {
            return type(int256).max;
        }

        return a + b;
    }

    /**
     * Returns a - b, the result is bounded to prevent overflows.
     * Note that this will revert if b is type(int256).min because of the usage of "-b".
     *
     * @param a the first number
     * @param b the second number
     * @return the bounded result of a - b
     */
    function boundedSub(int256 a, int256 b) internal pure returns (int256) {
        // if either a or b is zero or the signs are the same there should not be any overflow
        if (a == 0 || b == 0 || (a > 0 && b > 0) || (a < 0 && b < 0)) {
            return a - b;
        }

        // if adding `-b` to `a` would result in a value greater than the max int256 value
        // then return the max int256 value
        if (a > 0 && -b >= type(int256).max - a) {
            return type(int256).max;
        }

        // if subtracting `b` from `a` would result in a value less than the min int256 value
        // then return the min int256 value
        if (a < 0 && -b <= type(int256).min - a) {
            return type(int256).min;
        }

        return a - b;
    }


    /**
     * Converts the given unsigned integer to a signed integer, using the given
     * flag to determine whether the result should be positive or negative.
     *
     * @param a the unsigned integer to convert
     * @param isPositive whether the result should be positive (if true) or negative (if false)
     * @return the signed integer representation of the given unsigned integer
     */
    function toSigned(uint256 a, bool isPositive) internal pure returns (int256) {
        if (isPositive) {
            return a.toInt256();
        } else {
            return -a.toInt256();
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title Cast
 * @dev Library for casting functions
 */
library Cast {
    function toBytes32(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title EnumerableValues
 * @dev Library to extend the EnumerableSet library with functions to get
 * valuesAt for a range
 */
library EnumerableValues {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * Returns an array of bytes32 values from the given set, starting at the given
     * start index and ending before the given end index.
     *
     * @param set The set to get the values from.
     * @param start The starting index.
     * @param end The ending index.
     * @return An array of bytes32 values.
     */
    function valuesAt(EnumerableSet.Bytes32Set storage set, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        uint256 max = set.length();
        if (end > max) { end = max; }

        bytes32[] memory items = new bytes32[](end - start);
        for (uint256 i = start; i < end; i++) {
            items[i - start] = set.at(i);
        }

        return items;
    }


    /**
     * Returns an array of address values from the given set, starting at the given
     * start index and ending before the given end index.
     *
     * @param set The set to get the values from.
     * @param start The starting index.
     * @param end The ending index.
     * @return An array of address values.
     */
    function valuesAt(EnumerableSet.AddressSet storage set, uint256 start, uint256 end) internal view returns (address[] memory) {
        uint256 max = set.length();
        if (end > max) { end = max; }

        address[] memory items = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            items[i - start] = set.at(i);
        }

        return items;
    }


    /**
     * Returns an array of uint256 values from the given set, starting at the given
     * start index and ending before the given end index, the item at the end index will not be returned.
     *
     * @param set The set to get the values from.
     * @param start The starting index (inclusive, item at the start index will be returned).
     * @param end The ending index (exclusive, item at the end index will not be returned).
     * @return An array of uint256 values.
     */
    function valuesAt(EnumerableSet.UintSet storage set, uint256 start, uint256 end) internal view returns (uint256[] memory) {
        if (start >= set.length()) {
            return new uint256[](0);
        }

        uint256 max = set.length();
        if (end > max) { end = max; }

        uint256[] memory items = new uint256[](end - start);
        for (uint256 i = start; i < end; i++) {
            items[i - start] = set.at(i);
        }

        return items;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// there is a known issue with prb-math v3.x releases
// https://github.com/PaulRBerg/prb-math/issues/178
// due to this, either prb-math v2.x or v4.x versions should be used instead
import "prb-math/contracts/PRBMathUD60x18.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./Calc.sol";

/**
 * @title Precision
 * @dev Library for precision values and conversions
 */
library Precision {
    using SafeCast for uint256;
    using SignedMath for int256;

    uint256 public constant FLOAT_PRECISION = 10 ** 30;
    uint256 public constant FLOAT_PRECISION_SQRT = 10 ** 15;

    uint256 public constant WEI_PRECISION = 10 ** 18;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    uint256 public constant FLOAT_TO_WEI_DIVISOR = 10 ** 12;

    /**
     * Applies the given factor to the given value and returns the result.
     *
     * @param value The value to apply the factor to.
     * @param factor The factor to apply.
     * @return The result of applying the factor to the value.
     */
    function applyFactor(uint256 value, uint256 factor) internal pure returns (uint256) {
        return mulDiv(value, factor, FLOAT_PRECISION);
    }

    /**
     * Applies the given factor to the given value and returns the result.
     *
     * @param value The value to apply the factor to.
     * @param factor The factor to apply.
     * @return The result of applying the factor to the value.
     */
    function applyFactor(uint256 value, int256 factor) internal pure returns (int256) {
        return mulDiv(value, factor, FLOAT_PRECISION);
    }

    function applyFactor(uint256 value, int256 factor, bool roundUpMagnitude) internal pure returns (int256) {
        return mulDiv(value, factor, FLOAT_PRECISION, roundUpMagnitude);
    }

    function mulDiv(uint256 value, uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        return Math.mulDiv(value, numerator, denominator);
    }

    function mulDiv(int256 value, uint256 numerator, uint256 denominator) internal pure returns (int256) {
        return mulDiv(numerator, value, denominator);
    }

    function mulDiv(uint256 value, int256 numerator, uint256 denominator) internal pure returns (int256) {
        uint256 result = mulDiv(value, numerator.abs(), denominator);
        return numerator > 0 ? result.toInt256() : -result.toInt256();
    }

    function mulDiv(uint256 value, int256 numerator, uint256 denominator, bool roundUpMagnitude) internal pure returns (int256) {
        uint256 result = mulDiv(value, numerator.abs(), denominator, roundUpMagnitude);
        return numerator > 0 ? result.toInt256() : -result.toInt256();
    }

    function mulDiv(uint256 value, uint256 numerator, uint256 denominator, bool roundUpMagnitude) internal pure returns (uint256) {
        if (roundUpMagnitude) {
            return Math.mulDiv(value, numerator, denominator, Math.Rounding.Up);
        }

        return Math.mulDiv(value, numerator, denominator);
    }

    function applyExponentFactor(
        uint256 floatValue,
        uint256 exponentFactor
    ) internal pure returns (uint256) {
        // `PRBMathUD60x18.pow` doesn't work for `x` less than one
        if (floatValue < FLOAT_PRECISION) {
            return 0;
        }

        if (exponentFactor == FLOAT_PRECISION) {
            return floatValue;
        }

        // `PRBMathUD60x18.pow` accepts 2 fixed point numbers 60x18
        // we need to convert float (30 decimals) to 60x18 (18 decimals) and then back to 30 decimals
        uint256 weiValue = PRBMathUD60x18.pow(
            floatToWei(floatValue),
            floatToWei(exponentFactor)
        );

        return weiToFloat(weiValue);
    }

    function toFactor(uint256 value, uint256 divisor, bool roundUpMagnitude) internal pure returns (uint256) {
        if (value == 0) { return 0; }

        if (roundUpMagnitude) {
            return Math.mulDiv(value, FLOAT_PRECISION, divisor, Math.Rounding.Up);
        }

        return Math.mulDiv(value, FLOAT_PRECISION, divisor);
    }

    function toFactor(uint256 value, uint256 divisor) internal pure returns (uint256) {
        return toFactor(value, divisor, false);
    }

    function toFactor(int256 value, uint256 divisor) internal pure returns (int256) {
        uint256 result = toFactor(value.abs(), divisor);
        return value > 0 ? result.toInt256() : -result.toInt256();
    }

    /**
     * Converts the given value from float to wei.
     *
     * @param value The value to convert.
     * @return The converted value in wei.
     */
    function floatToWei(uint256 value) internal pure returns (uint256) {
        return value / FLOAT_TO_WEI_DIVISOR;
    }

    /**
     * Converts the given value from wei to float.
     *
     * @param value The value to convert.
     * @return The converted value in float.
     */
    function weiToFloat(uint256 value) internal pure returns (uint256) {
        return value * FLOAT_TO_WEI_DIVISOR;
    }

    /**
     * Converts the given number of basis points to float.
     *
     * @param basisPoints The number of basis points to convert.
     * @return The converted value in float.
     */
    function basisPointsToFloat(uint256 basisPoints) internal pure returns (uint256) {
        return basisPoints * FLOAT_PRECISION / BASIS_POINTS_DIVISOR;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "hardhat/console.sol";

/**
 * @title Printer
 * @dev Library for console functions
 */
library Printer {
    using SafeCast for int256;

    function log(string memory label, int256 value) internal view {
        if (value < 0) {
            console.log(
                "%s -%s",
                label,
                (-value).toUint256()
            );
        } else {
            console.log(
                "%s +%s",
                label,
                value.toUint256()
            );
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../error/Errors.sol";

library Uint256Mask {
    struct Mask {
        uint256 bits;
    }

    function validateUniqueAndSetIndex(
        Mask memory mask,
        uint256 index,
        string memory label
    ) internal pure {
        if (index >= 256) {
            revert Errors.MaskIndexOutOfBounds(index, label);
        }

        uint256 bit = 1 << index;

        if (mask.bits & bit != 0) {
            revert Errors.DuplicatedIndex(index, label);
        }

        mask.bits = mask.bits | bit;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.9.0;

library console {
	address constant CONSOLE_ADDRESS = 0x000000000000000000636F6e736F6c652e6c6f67;

	function _sendLogPayload(bytes memory payload) private view {
		address consoleAddress = CONSOLE_ADDRESS;
		/// @solidity memory-safe-assembly
		assembly {
			pop(staticcall(gas(), consoleAddress, add(payload, 32), mload(payload), 0, 0))
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int256)", p0));
	}

	function logUint(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint256 p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256)", p0, p1));
	}

	function log(uint256 p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string)", p0, p1));
	}

	function log(uint256 p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool)", p0, p1));
	}

	function log(uint256 p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address)", p0, p1));
	}

	function log(string memory p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint256 p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivFixedPointOverflow(uint256 prod1);

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivOverflow(uint256 prod1, uint256 denominator);

/// @notice Emitted when one of the inputs is type(int256).min.
error PRBMath__MulDivSignedInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows int256.
error PRBMath__MulDivSignedOverflow(uint256 rAbs);

/// @notice Emitted when the input is MIN_SD59x18.
error PRBMathSD59x18__AbsInputTooSmall();

/// @notice Emitted when ceiling a number overflows SD59x18.
error PRBMathSD59x18__CeilOverflow(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__DivInputTooSmall();

/// @notice Emitted when one of the intermediary unsigned results overflows SD59x18.
error PRBMathSD59x18__DivOverflow(uint256 rAbs);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathSD59x18__ExpInputTooBig(int256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathSD59x18__Exp2InputTooBig(int256 x);

/// @notice Emitted when flooring a number underflows SD59x18.
error PRBMathSD59x18__FloorUnderflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMathSD59x18__FromIntOverflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMathSD59x18__FromIntUnderflow(int256 x);

/// @notice Emitted when the product of the inputs is negative.
error PRBMathSD59x18__GmNegativeProduct(int256 x, int256 y);

/// @notice Emitted when multiplying the inputs overflows SD59x18.
error PRBMathSD59x18__GmOverflow(int256 x, int256 y);

/// @notice Emitted when the input is less than or equal to zero.
error PRBMathSD59x18__LogInputTooSmall(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__MulInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__MulOverflow(uint256 rAbs);

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__PowuOverflow(uint256 rAbs);

/// @notice Emitted when the input is negative.
error PRBMathSD59x18__SqrtNegativeInput(int256 x);

/// @notice Emitted when the calculating the square root overflows SD59x18.
error PRBMathSD59x18__SqrtOverflow(int256 x);

/// @notice Emitted when addition overflows UD60x18.
error PRBMathUD60x18__AddOverflow(uint256 x, uint256 y);

/// @notice Emitted when ceiling a number overflows UD60x18.
error PRBMathUD60x18__CeilOverflow(uint256 x);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathUD60x18__ExpInputTooBig(uint256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathUD60x18__Exp2InputTooBig(uint256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format format overflows UD60x18.
error PRBMathUD60x18__FromUintOverflow(uint256 x);

/// @notice Emitted when multiplying the inputs overflows UD60x18.
error PRBMathUD60x18__GmOverflow(uint256 x, uint256 y);

/// @notice Emitted when the input is less than 1.
error PRBMathUD60x18__LogInputTooSmall(uint256 x);

/// @notice Emitted when the calculating the square root overflows UD60x18.
error PRBMathUD60x18__SqrtOverflow(uint256 x);

/// @notice Emitted when subtraction underflows UD60x18.
error PRBMathUD60x18__SubUnderflow(uint256 x, uint256 y);

/// @dev Common mathematical functions used in both PRBMathSD59x18 and PRBMathUD60x18. Note that this shared library
/// does not always assume the signed 59.18-decimal fixed-point or the unsigned 60.18-decimal fixed-point
/// representation. When it does not, it is explicitly mentioned in the NatSpec documentation.
library PRBMath {
    /// STRUCTS ///

    struct SD59x18 {
        int256 value;
    }

    struct UD60x18 {
        uint256 value;
    }

    /// STORAGE ///

    /// @dev How many trailing decimals can be represented.
    uint256 internal constant SCALE = 1e18;

    /// @dev Largest power of two divisor of SCALE.
    uint256 internal constant SCALE_LPOTD = 262144;

    /// @dev SCALE inverted mod 2^256.
    uint256 internal constant SCALE_INVERSE =
        78156646155174841979727994598816262306175212592076161876661_508869554232690281;

    /// FUNCTIONS ///

    /// @notice Calculates the binary exponent of x using the binary fraction method.
    /// @dev Has to use 192.64-bit fixed-point numbers.
    /// See https://ethereum.stackexchange.com/a/96594/24693.
    /// @param x The exponent as an unsigned 192.64-bit fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function exp2(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            // Start from 0.5 in the 192.64-bit fixed-point format.
            result = 0x800000000000000000000000000000000000000000000000;

            // Multiply the result by root(2, 2^-i) when the bit at position i is 1. None of the intermediary results overflows
            // because the initial result is 2^191 and all magic factors are less than 2^65.
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }

            // We're doing two things at the same time:
            //
            //   1. Multiply the result by 2^n + 1, where "2^n" is the integer part and the one is added to account for
            //      the fact that we initially set the result to 0.5. This is accomplished by subtracting from 191
            //      rather than 192.
            //   2. Convert the result to the unsigned 60.18-decimal fixed-point format.
            //
            // This works because 2^(191-ip) = 2^ip / 2^191, where "ip" is the integer part "2^n".
            result *= SCALE;
            result >>= (191 - (x >> 64));
        }
    }

    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            // No need to shift x any more.
            msb += 1;
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
    ///
    /// Requirements:
    /// - The denominator cannot be zero.
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The multiplicand as an uint256.
    /// @param y The multiplier as an uint256.
    /// @param denominator The divisor as an uint256.
    /// @return result The result as an uint256.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division.
        if (prod1 == 0) {
            unchecked {
                result = prod0 / denominator;
            }
            return result;
        }

        // Make sure the result is less than 2^256. Also prevents denominator == 0.
        if (prod1 >= denominator) {
            revert PRBMath__MulDivOverflow(prod1, denominator);
        }

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0].
        uint256 remainder;
        assembly {
            // Compute remainder using mulmod.
            remainder := mulmod(x, y, denominator)

            // Subtract 256 bit number from 512 bit number.
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
        // See https://cs.stackexchange.com/q/138556/92363.
        unchecked {
            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 lpotdod = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by lpotdod.
                denominator := div(denominator, lpotdod)

                // Divide [prod1 prod0] by lpotdod.
                prod0 := div(prod0, lpotdod)

                // Flip lpotdod such that it is 2^256 / lpotdod. If lpotdod is zero, then it becomes one.
                lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * lpotdod;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /// @notice Calculates floor(x*y÷1e18) with full precision.
    ///
    /// @dev Variant of "mulDiv" with constant folding, i.e. in which the denominator is always 1e18. Before returning the
    /// final result, we add 1 if (x * y) % SCALE >= HALF_SCALE. Without this, 6.6e-19 would be truncated to 0 instead of
    /// being rounded to 1e-18.  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717.
    ///
    /// Requirements:
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - The body is purposely left uncommented; see the NatSpec comments in "PRBMath.mulDiv" to understand how this works.
    /// - It is assumed that the result can never be type(uint256).max when x and y solve the following two equations:
    ///     1. x * y = type(uint256).max * SCALE
    ///     2. (x * y) % SCALE >= SCALE / 2
    ///
    /// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
    /// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function mulDivFixedPoint(uint256 x, uint256 y) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 >= SCALE) {
            revert PRBMath__MulDivFixedPointOverflow(prod1);
        }

        uint256 remainder;
        uint256 roundUpUnit;
        assembly {
            remainder := mulmod(x, y, SCALE)
            roundUpUnit := gt(remainder, 499999999999999999)
        }

        if (prod1 == 0) {
            unchecked {
                result = (prod0 / SCALE) + roundUpUnit;
                return result;
            }
        }

        assembly {
            result := add(
                mul(
                    or(
                        div(sub(prod0, remainder), SCALE_LPOTD),
                        mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, SCALE_LPOTD), SCALE_LPOTD), 1))
                    ),
                    SCALE_INVERSE
                ),
                roundUpUnit
            )
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev An extension of "mulDiv" for signed numbers. Works by computing the signs and the absolute values separately.
    ///
    /// Requirements:
    /// - None of the inputs can be type(int256).min.
    /// - The result must fit within int256.
    ///
    /// @param x The multiplicand as an int256.
    /// @param y The multiplier as an int256.
    /// @param denominator The divisor as an int256.
    /// @return result The result as an int256.
    function mulDivSigned(
        int256 x,
        int256 y,
        int256 denominator
    ) internal pure returns (int256 result) {
        if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
            revert PRBMath__MulDivSignedInputTooSmall();
        }

        // Get hold of the absolute values of x, y and the denominator.
        uint256 ax;
        uint256 ay;
        uint256 ad;
        unchecked {
            ax = x < 0 ? uint256(-x) : uint256(x);
            ay = y < 0 ? uint256(-y) : uint256(y);
            ad = denominator < 0 ? uint256(-denominator) : uint256(denominator);
        }

        // Compute the absolute value of (x*y)÷denominator. The result must fit within int256.
        uint256 rAbs = mulDiv(ax, ay, ad);
        if (rAbs > uint256(type(int256).max)) {
            revert PRBMath__MulDivSignedOverflow(rAbs);
        }

        // Get the signs of x, y and the denominator.
        uint256 sx;
        uint256 sy;
        uint256 sd;
        assembly {
            sx := sgt(x, sub(0, 1))
            sy := sgt(y, sub(0, 1))
            sd := sgt(denominator, sub(0, 1))
        }

        // XOR over sx, sy and sd. This is checking whether there are one or three negative signs in the inputs.
        // If yes, the result should be negative.
        result = sx ^ sy ^ sd == 0 ? -int256(rAbs) : int256(rAbs);
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }

        // Set the initial guess to the least power of two that is greater than or equal to sqrt(x).
        uint256 xAux = uint256(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }

        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint256 roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

import "./PRBMath.sol";

/// @title PRBMathUD60x18
/// @author Paul Razvan Berg
/// @notice Smart contract library for advanced fixed-point math that works with uint256 numbers considered to have 18
/// trailing decimals. We call this number representation unsigned 60.18-decimal fixed-point, since there can be up to 60
/// digits in the integer part and up to 18 decimals in the fractional part. The numbers are bound by the minimum and the
/// maximum values permitted by the Solidity type uint256.
library PRBMathUD60x18 {
    /// @dev Half the SCALE number.
    uint256 internal constant HALF_SCALE = 5e17;

    /// @dev log2(e) as an unsigned 60.18-decimal fixed-point number.
    uint256 internal constant LOG2_E = 1_442695040888963407;

    /// @dev The maximum value an unsigned 60.18-decimal fixed-point number can have.
    uint256 internal constant MAX_UD60x18 =
        115792089237316195423570985008687907853269984665640564039457_584007913129639935;

    /// @dev The maximum whole value an unsigned 60.18-decimal fixed-point number can have.
    uint256 internal constant MAX_WHOLE_UD60x18 =
        115792089237316195423570985008687907853269984665640564039457_000000000000000000;

    /// @dev How many trailing decimals can be represented.
    uint256 internal constant SCALE = 1e18;

    /// @notice Calculates the arithmetic average of x and y, rounding down.
    /// @param x The first operand as an unsigned 60.18-decimal fixed-point number.
    /// @param y The second operand as an unsigned 60.18-decimal fixed-point number.
    /// @return result The arithmetic average as an unsigned 60.18-decimal fixed-point number.
    function avg(uint256 x, uint256 y) internal pure returns (uint256 result) {
        // The operations can never overflow.
        unchecked {
            // The last operand checks if both x and y are odd and if that is the case, we add 1 to the result. We need
            // to do this because if both numbers are odd, the 0.5 remainder gets truncated twice.
            result = (x >> 1) + (y >> 1) + (x & y & 1);
        }
    }

    /// @notice Yields the least unsigned 60.18 decimal fixed-point number greater than or equal to x.
    ///
    /// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
    /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
    ///
    /// Requirements:
    /// - x must be less than or equal to MAX_WHOLE_UD60x18.
    ///
    /// @param x The unsigned 60.18-decimal fixed-point number to ceil.
    /// @param result The least integer greater than or equal to x, as an unsigned 60.18-decimal fixed-point number.
    function ceil(uint256 x) internal pure returns (uint256 result) {
        if (x > MAX_WHOLE_UD60x18) {
            revert PRBMathUD60x18__CeilOverflow(x);
        }
        assembly {
            // Equivalent to "x % SCALE" but faster.
            let remainder := mod(x, SCALE)

            // Equivalent to "SCALE - remainder" but faster.
            let delta := sub(SCALE, remainder)

            // Equivalent to "x + delta * (remainder > 0 ? 1 : 0)" but faster.
            result := add(x, mul(delta, gt(remainder, 0)))
        }
    }

    /// @notice Divides two unsigned 60.18-decimal fixed-point numbers, returning a new unsigned 60.18-decimal fixed-point number.
    ///
    /// @dev Uses mulDiv to enable overflow-safe multiplication and division.
    ///
    /// Requirements:
    /// - The denominator cannot be zero.
    ///
    /// @param x The numerator as an unsigned 60.18-decimal fixed-point number.
    /// @param y The denominator as an unsigned 60.18-decimal fixed-point number.
    /// @param result The quotient as an unsigned 60.18-decimal fixed-point number.
    function div(uint256 x, uint256 y) internal pure returns (uint256 result) {
        result = PRBMath.mulDiv(x, SCALE, y);
    }

    /// @notice Returns Euler's number as an unsigned 60.18-decimal fixed-point number.
    /// @dev See https://en.wikipedia.org/wiki/E_(mathematical_constant).
    function e() internal pure returns (uint256 result) {
        result = 2_718281828459045235;
    }

    /// @notice Calculates the natural exponent of x.
    ///
    /// @dev Based on the insight that e^x = 2^(x * log2(e)).
    ///
    /// Requirements:
    /// - All from "log2".
    /// - x must be less than 133.084258667509499441.
    ///
    /// @param x The exponent as an unsigned 60.18-decimal fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function exp(uint256 x) internal pure returns (uint256 result) {
        // Without this check, the value passed to "exp2" would be greater than 192.
        if (x >= 133_084258667509499441) {
            revert PRBMathUD60x18__ExpInputTooBig(x);
        }

        // Do the fixed-point multiplication inline to save gas.
        unchecked {
            uint256 doubleScaleProduct = x * LOG2_E;
            result = exp2((doubleScaleProduct + HALF_SCALE) / SCALE);
        }
    }

    /// @notice Calculates the binary exponent of x using the binary fraction method.
    ///
    /// @dev See https://ethereum.stackexchange.com/q/79903/24693.
    ///
    /// Requirements:
    /// - x must be 192 or less.
    /// - The result must fit within MAX_UD60x18.
    ///
    /// @param x The exponent as an unsigned 60.18-decimal fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function exp2(uint256 x) internal pure returns (uint256 result) {
        // 2^192 doesn't fit within the 192.64-bit format used internally in this function.
        if (x >= 192e18) {
            revert PRBMathUD60x18__Exp2InputTooBig(x);
        }

        unchecked {
            // Convert x to the 192.64-bit fixed-point format.
            uint256 x192x64 = (x << 64) / SCALE;

            // Pass x to the PRBMath.exp2 function, which uses the 192.64-bit fixed-point number representation.
            result = PRBMath.exp2(x192x64);
        }
    }

    /// @notice Yields the greatest unsigned 60.18 decimal fixed-point number less than or equal to x.
    /// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
    /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
    /// @param x The unsigned 60.18-decimal fixed-point number to floor.
    /// @param result The greatest integer less than or equal to x, as an unsigned 60.18-decimal fixed-point number.
    function floor(uint256 x) internal pure returns (uint256 result) {
        assembly {
            // Equivalent to "x % SCALE" but faster.
            let remainder := mod(x, SCALE)

            // Equivalent to "x - remainder * (remainder > 0 ? 1 : 0)" but faster.
            result := sub(x, mul(remainder, gt(remainder, 0)))
        }
    }

    /// @notice Yields the excess beyond the floor of x.
    /// @dev Based on the odd function definition https://en.wikipedia.org/wiki/Fractional_part.
    /// @param x The unsigned 60.18-decimal fixed-point number to get the fractional part of.
    /// @param result The fractional part of x as an unsigned 60.18-decimal fixed-point number.
    function frac(uint256 x) internal pure returns (uint256 result) {
        assembly {
            result := mod(x, SCALE)
        }
    }

    /// @notice Converts a number from basic integer form to unsigned 60.18-decimal fixed-point representation.
    ///
    /// @dev Requirements:
    /// - x must be less than or equal to MAX_UD60x18 divided by SCALE.
    ///
    /// @param x The basic integer to convert.
    /// @param result The same number in unsigned 60.18-decimal fixed-point representation.
    function fromUint(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            if (x > MAX_UD60x18 / SCALE) {
                revert PRBMathUD60x18__FromUintOverflow(x);
            }
            result = x * SCALE;
        }
    }

    /// @notice Calculates geometric mean of x and y, i.e. sqrt(x * y), rounding down.
    ///
    /// @dev Requirements:
    /// - x * y must fit within MAX_UD60x18, lest it overflows.
    ///
    /// @param x The first operand as an unsigned 60.18-decimal fixed-point number.
    /// @param y The second operand as an unsigned 60.18-decimal fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function gm(uint256 x, uint256 y) internal pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }

        unchecked {
            // Checking for overflow this way is faster than letting Solidity do it.
            uint256 xy = x * y;
            if (xy / x != y) {
                revert PRBMathUD60x18__GmOverflow(x, y);
            }

            // We don't need to multiply by the SCALE here because the x*y product had already picked up a factor of SCALE
            // during multiplication. See the comments within the "sqrt" function.
            result = PRBMath.sqrt(xy);
        }
    }

    /// @notice Calculates 1 / x, rounding toward zero.
    ///
    /// @dev Requirements:
    /// - x cannot be zero.
    ///
    /// @param x The unsigned 60.18-decimal fixed-point number for which to calculate the inverse.
    /// @return result The inverse as an unsigned 60.18-decimal fixed-point number.
    function inv(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            // 1e36 is SCALE * SCALE.
            result = 1e36 / x;
        }
    }

    /// @notice Calculates the natural logarithm of x.
    ///
    /// @dev Based on the insight that ln(x) = log2(x) / log2(e).
    ///
    /// Requirements:
    /// - All from "log2".
    ///
    /// Caveats:
    /// - All from "log2".
    /// - This doesn't return exactly 1 for 2.718281828459045235, for that we would need more fine-grained precision.
    ///
    /// @param x The unsigned 60.18-decimal fixed-point number for which to calculate the natural logarithm.
    /// @return result The natural logarithm as an unsigned 60.18-decimal fixed-point number.
    function ln(uint256 x) internal pure returns (uint256 result) {
        // Do the fixed-point multiplication inline to save gas. This is overflow-safe because the maximum value that log2(x)
        // can return is 196205294292027477728.
        unchecked {
            result = (log2(x) * SCALE) / LOG2_E;
        }
    }

    /// @notice Calculates the common logarithm of x.
    ///
    /// @dev First checks if x is an exact power of ten and it stops if yes. If it's not, calculates the common
    /// logarithm based on the insight that log10(x) = log2(x) / log2(10).
    ///
    /// Requirements:
    /// - All from "log2".
    ///
    /// Caveats:
    /// - All from "log2".
    ///
    /// @param x The unsigned 60.18-decimal fixed-point number for which to calculate the common logarithm.
    /// @return result The common logarithm as an unsigned 60.18-decimal fixed-point number.
    function log10(uint256 x) internal pure returns (uint256 result) {
        if (x < SCALE) {
            revert PRBMathUD60x18__LogInputTooSmall(x);
        }

        // Note that the "mul" in this block is the assembly multiplication operation, not the "mul" function defined
        // in this contract.
        // prettier-ignore
        assembly {
            switch x
            case 1 { result := mul(SCALE, sub(0, 18)) }
            case 10 { result := mul(SCALE, sub(1, 18)) }
            case 100 { result := mul(SCALE, sub(2, 18)) }
            case 1000 { result := mul(SCALE, sub(3, 18)) }
            case 10000 { result := mul(SCALE, sub(4, 18)) }
            case 100000 { result := mul(SCALE, sub(5, 18)) }
            case 1000000 { result := mul(SCALE, sub(6, 18)) }
            case 10000000 { result := mul(SCALE, sub(7, 18)) }
            case 100000000 { result := mul(SCALE, sub(8, 18)) }
            case 1000000000 { result := mul(SCALE, sub(9, 18)) }
            case 10000000000 { result := mul(SCALE, sub(10, 18)) }
            case 100000000000 { result := mul(SCALE, sub(11, 18)) }
            case 1000000000000 { result := mul(SCALE, sub(12, 18)) }
            case 10000000000000 { result := mul(SCALE, sub(13, 18)) }
            case 100000000000000 { result := mul(SCALE, sub(14, 18)) }
            case 1000000000000000 { result := mul(SCALE, sub(15, 18)) }
            case 10000000000000000 { result := mul(SCALE, sub(16, 18)) }
            case 100000000000000000 { result := mul(SCALE, sub(17, 18)) }
            case 1000000000000000000 { result := 0 }
            case 10000000000000000000 { result := SCALE }
            case 100000000000000000000 { result := mul(SCALE, 2) }
            case 1000000000000000000000 { result := mul(SCALE, 3) }
            case 10000000000000000000000 { result := mul(SCALE, 4) }
            case 100000000000000000000000 { result := mul(SCALE, 5) }
            case 1000000000000000000000000 { result := mul(SCALE, 6) }
            case 10000000000000000000000000 { result := mul(SCALE, 7) }
            case 100000000000000000000000000 { result := mul(SCALE, 8) }
            case 1000000000000000000000000000 { result := mul(SCALE, 9) }
            case 10000000000000000000000000000 { result := mul(SCALE, 10) }
            case 100000000000000000000000000000 { result := mul(SCALE, 11) }
            case 1000000000000000000000000000000 { result := mul(SCALE, 12) }
            case 10000000000000000000000000000000 { result := mul(SCALE, 13) }
            case 100000000000000000000000000000000 { result := mul(SCALE, 14) }
            case 1000000000000000000000000000000000 { result := mul(SCALE, 15) }
            case 10000000000000000000000000000000000 { result := mul(SCALE, 16) }
            case 100000000000000000000000000000000000 { result := mul(SCALE, 17) }
            case 1000000000000000000000000000000000000 { result := mul(SCALE, 18) }
            case 10000000000000000000000000000000000000 { result := mul(SCALE, 19) }
            case 100000000000000000000000000000000000000 { result := mul(SCALE, 20) }
            case 1000000000000000000000000000000000000000 { result := mul(SCALE, 21) }
            case 10000000000000000000000000000000000000000 { result := mul(SCALE, 22) }
            case 100000000000000000000000000000000000000000 { result := mul(SCALE, 23) }
            case 1000000000000000000000000000000000000000000 { result := mul(SCALE, 24) }
            case 10000000000000000000000000000000000000000000 { result := mul(SCALE, 25) }
            case 100000000000000000000000000000000000000000000 { result := mul(SCALE, 26) }
            case 1000000000000000000000000000000000000000000000 { result := mul(SCALE, 27) }
            case 10000000000000000000000000000000000000000000000 { result := mul(SCALE, 28) }
            case 100000000000000000000000000000000000000000000000 { result := mul(SCALE, 29) }
            case 1000000000000000000000000000000000000000000000000 { result := mul(SCALE, 30) }
            case 10000000000000000000000000000000000000000000000000 { result := mul(SCALE, 31) }
            case 100000000000000000000000000000000000000000000000000 { result := mul(SCALE, 32) }
            case 1000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 33) }
            case 10000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 34) }
            case 100000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 35) }
            case 1000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 36) }
            case 10000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 37) }
            case 100000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 38) }
            case 1000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 39) }
            case 10000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 40) }
            case 100000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 41) }
            case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 42) }
            case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 43) }
            case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 44) }
            case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 45) }
            case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 46) }
            case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 47) }
            case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 48) }
            case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 49) }
            case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 50) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 51) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 52) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 53) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 54) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 55) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 56) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 57) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 58) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 59) }
            default {
                result := MAX_UD60x18
            }
        }

        if (result == MAX_UD60x18) {
            // Do the fixed-point division inline to save gas. The denominator is log2(10).
            unchecked {
                result = (log2(x) * SCALE) / 3_321928094887362347;
            }
        }
    }

    /// @notice Calculates the binary logarithm of x.
    ///
    /// @dev Based on the iterative approximation algorithm.
    /// https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
    ///
    /// Requirements:
    /// - x must be greater than or equal to SCALE, otherwise the result would be negative.
    ///
    /// Caveats:
    /// - The results are nor perfectly accurate to the last decimal, due to the lossy precision of the iterative approximation.
    ///
    /// @param x The unsigned 60.18-decimal fixed-point number for which to calculate the binary logarithm.
    /// @return result The binary logarithm as an unsigned 60.18-decimal fixed-point number.
    function log2(uint256 x) internal pure returns (uint256 result) {
        if (x < SCALE) {
            revert PRBMathUD60x18__LogInputTooSmall(x);
        }
        unchecked {
            // Calculate the integer part of the logarithm and add it to the result and finally calculate y = x * 2^(-n).
            uint256 n = PRBMath.mostSignificantBit(x / SCALE);

            // The integer part of the logarithm as an unsigned 60.18-decimal fixed-point number. The operation can't overflow
            // because n is maximum 255 and SCALE is 1e18.
            result = n * SCALE;

            // This is y = x * 2^(-n).
            uint256 y = x >> n;

            // If y = 1, the fractional part is zero.
            if (y == SCALE) {
                return result;
            }

            // Calculate the fractional part via the iterative approximation.
            // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
            for (uint256 delta = HALF_SCALE; delta > 0; delta >>= 1) {
                y = (y * y) / SCALE;

                // Is y^2 > 2 and so in the range [2,4)?
                if (y >= 2 * SCALE) {
                    // Add the 2^(-m) factor to the logarithm.
                    result += delta;

                    // Corresponds to z/2 on Wikipedia.
                    y >>= 1;
                }
            }
        }
    }

    /// @notice Multiplies two unsigned 60.18-decimal fixed-point numbers together, returning a new unsigned 60.18-decimal
    /// fixed-point number.
    /// @dev See the documentation for the "PRBMath.mulDivFixedPoint" function.
    /// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
    /// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
    /// @return result The product as an unsigned 60.18-decimal fixed-point number.
    function mul(uint256 x, uint256 y) internal pure returns (uint256 result) {
        result = PRBMath.mulDivFixedPoint(x, y);
    }

    /// @notice Returns PI as an unsigned 60.18-decimal fixed-point number.
    function pi() internal pure returns (uint256 result) {
        result = 3_141592653589793238;
    }

    /// @notice Raises x to the power of y.
    ///
    /// @dev Based on the insight that x^y = 2^(log2(x) * y).
    ///
    /// Requirements:
    /// - All from "exp2", "log2" and "mul".
    ///
    /// Caveats:
    /// - All from "exp2", "log2" and "mul".
    /// - Assumes 0^0 is 1.
    ///
    /// @param x Number to raise to given power y, as an unsigned 60.18-decimal fixed-point number.
    /// @param y Exponent to raise x to, as an unsigned 60.18-decimal fixed-point number.
    /// @return result x raised to power y, as an unsigned 60.18-decimal fixed-point number.
    function pow(uint256 x, uint256 y) internal pure returns (uint256 result) {
        if (x == 0) {
            result = y == 0 ? SCALE : uint256(0);
        } else {
            result = exp2(mul(log2(x), y));
        }
    }

    /// @notice Raises x (unsigned 60.18-decimal fixed-point number) to the power of y (basic unsigned integer) using the
    /// famous algorithm "exponentiation by squaring".
    ///
    /// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring
    ///
    /// Requirements:
    /// - The result must fit within MAX_UD60x18.
    ///
    /// Caveats:
    /// - All from "mul".
    /// - Assumes 0^0 is 1.
    ///
    /// @param x The base as an unsigned 60.18-decimal fixed-point number.
    /// @param y The exponent as an uint256.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function powu(uint256 x, uint256 y) internal pure returns (uint256 result) {
        // Calculate the first iteration of the loop in advance.
        result = y & 1 > 0 ? x : SCALE;

        // Equivalent to "for(y /= 2; y > 0; y /= 2)" but faster.
        for (y >>= 1; y > 0; y >>= 1) {
            x = PRBMath.mulDivFixedPoint(x, x);

            // Equivalent to "y % 2 == 1" but faster.
            if (y & 1 > 0) {
                result = PRBMath.mulDivFixedPoint(result, x);
            }
        }
    }

    /// @notice Returns 1 as an unsigned 60.18-decimal fixed-point number.
    function scale() internal pure returns (uint256 result) {
        result = SCALE;
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Requirements:
    /// - x must be less than MAX_UD60x18 / SCALE.
    ///
    /// @param x The unsigned 60.18-decimal fixed-point number for which to calculate the square root.
    /// @return result The result as an unsigned 60.18-decimal fixed-point .
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            if (x > MAX_UD60x18 / SCALE) {
                revert PRBMathUD60x18__SqrtOverflow(x);
            }
            // Multiply x by the SCALE to account for the factor of SCALE that is picked up when multiplying two unsigned
            // 60.18-decimal fixed-point numbers together (in this case, those two numbers are both the square root).
            result = PRBMath.sqrt(x * SCALE);
        }
    }

    /// @notice Converts a unsigned 60.18-decimal fixed-point number to basic integer form, rounding down in the process.
    /// @param x The unsigned 60.18-decimal fixed-point number to convert.
    /// @return result The same number in basic integer form.
    function toUint(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            result = x / SCALE;
        }
    }
}