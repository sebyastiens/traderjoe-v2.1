// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

library BitMath {
    /// @notice Returns the non-zero bit closest to the `_integer` to the right (or left) of the `bit` index
    /// @param _integer The integer as a uint256
    /// @param _bit The bit index
    /// @param _leftSide Whether we're searching in the left side of the tree (true) or the right side (false)
    /// @return The index of the closest non zero bit
    /// @return Whether it was found (true), or not (false)
    function closestBit(
        uint256 _integer,
        uint256 _bit,
        bool _leftSide
    ) internal pure returns (uint256, bool) {
        unchecked {
            if (_leftSide) {
                return closestBitLeft(_integer, _bit + 1);
            }
            return closestBitRight(_integer, _bit - 1);
        }
    }

    /// @notice Returns the most (or least) significant bit of `_integer`
    /// @param _integer The integer
    /// @param _isMostSignificant Whether we want the most (true) or the least (false) significant bit
    /// @return The index of the most (or least) significant bit
    function significantBit(uint256 _integer, bool _isMostSignificant) internal pure returns (uint256) {
        if (_isMostSignificant) {
            return mostSignificantBit(_integer);
        }
        return leastSignificantBit(_integer);
    }

    /// @notice Returns a tuple (uint256 id, bool found),
    /// id is the index of the closest bit on the right of x that is non null
    /// @param x The value as a uint256
    /// @param bit The index of the bit to start searching at
    /// @return id The index of the closest non null bit on the right of x
    /// @return found If the index was found
    function closestBitRight(uint256 x, uint256 bit) internal pure returns (uint256 id, bool found) {
        unchecked {
            x <<= 255 - bit;

            if (x == 0) {
                return (0, false);
            }

            return (mostSignificantBit(x) - (255 - bit), true);
        }
    }

    /// @notice Returns a tuple (uint256 id, bool found),
    /// id is the index of the closest bit on the left of x that is non null
    /// @param x The value as a uint256
    /// @param bit The index of the bit to start searching at
    /// @return id The index of the closest non null bit on the left of x
    /// @return found If the index was found
    function closestBitLeft(uint256 x, uint256 bit) internal pure returns (uint256 id, bool found) {
        unchecked {
            x >>= bit;

            if (x == 0) {
                return (0, false);
            }

            return (leastSignificantBit(x) + bit, true);
        }
    }

    /// @notice Returns the index of the most significant bit of x
    /// @param x The value as a uint256
    /// @return msb The index of the most significant bit of x
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        unchecked {
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
                msb += 1;
            }
        }
    }

    /// @notice Returns the index of the least significant bit of x
    /// @param x The value as a uint256
    /// @return lsb The index of the least significant bit of x
    function leastSignificantBit(uint256 x) internal pure returns (uint256 lsb) {
        unchecked {
            if (x << 128 != 0) {
                x <<= 128;
                lsb += 128;
            }
            if (x << 64 != 0) {
                x <<= 64;
                lsb += 64;
            }
            if (x << 32 != 0) {
                x <<= 32;
                lsb += 32;
            }
            if (x << 16 != 0) {
                x <<= 16;
                lsb += 16;
            }
            if (x << 8 != 0) {
                x <<= 8;
                lsb += 8;
            }
            if (x << 4 != 0) {
                x <<= 4;
                lsb += 4;
            }
            if (x << 2 != 0) {
                x <<= 2;
                lsb += 2;
            }
            if (x << 1 != 0) {
                lsb += 1;
            }

            return 255 - lsb;
        }
    }
}
