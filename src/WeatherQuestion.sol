// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @dev Internal functions are embedded in the organism; no separately deployed library.
library WeatherQuestion {
    error InvalidCell();
    error InvalidDay();

    function validate(uint32 cell) internal pure {
        int16 lat = int16(uint16(cell >> 16));
        int16 lon = int16(uint16(cell));
        if (cell == 0 || lat < -360 || lat > 359 || lon < -720 || lon > 719) revert InvalidCell();
    }

    function coordinate(int16 quarter) internal pure returns (string memory) {
        int256 milli = int256(quarter) * 250 + 125;
        uint256 magnitude = uint256(milli < 0 ? -milli : milli);
        return string.concat(milli < 0 ? "-" : "", Strings.toString(magnitude / 1000), ".", pad(magnitude % 1000, 3));
    }

    function pad(uint256 n, uint256 length) private pure returns (string memory) {
        bytes memory b = new bytes(length);
        for (uint256 i = length; i > 0;) {
            b[--i] = bytes1(uint8(48 + n % 10));
            n /= 10;
        }
        return string(b);
    }

    /// @dev Gregorian civil-from-days (400-year eras), Unix epoch; years 1970..9999.
    function date(uint32 day) internal pure returns (string memory) {
        if (day > 2932896) revert InvalidDay();
        uint256 z = uint256(day) + 719468;
        uint256 era = z / 146097;
        uint256 doe = z % 146097;
        uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        uint256 y = yoe + era * 400;
        uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        uint256 mp = (5 * doy + 2) / 153;
        uint256 d = doy - (153 * mp + 2) / 5 + 1;
        uint256 m = mp < 10 ? mp + 3 : mp - 9;
        if (m <= 2) ++y;
        return string.concat(pad(y, 4), "-", pad(m, 2), "-", pad(d, 2));
    }

    function question(uint32 cell, uint32 day) internal pure returns (string memory) {
        validate(cell);
        string memory lat = coordinate(int16(uint16(cell >> 16)));
        string memory lon = coordinate(int16(uint16(cell)));
        string memory dt = date(day);
        return string.concat(
            "weather at latitude ",
            lat,
            " longitude ",
            lon,
            " on ",
            dt,
            " utc, from https://api.open-meteo.com/v1/forecast?latitude=",
            lat,
            "&longitude=",
            lon,
            "&past_days=92&hourly=is_day,cloud_cover,precipitation&timezone=UTC, the 24 rows of ",
            dt,
            ". hour h (0..23) is SUNNY if is_day=1 and cloud_cover<50 and precipitation=0; RAINY if precipitation>=0.2. answer one bytes32 = sunMask | rainMask<<24 | complete<<48 | ",
            Strings.toString(day),
            "<<96, bit h of each mask = hour h; complete = 1 if all 24 rows have values, else 0 with masks 0."
        );
    }

    function body(uint32 cell, uint32 day) internal pure returns (bytes memory) {
        // Every character comes from the fixed ASCII template or formatted integers: none needs
        // JSON escaping. There is no user-supplied text, quote, backslash or control character.
        return bytes(
            string.concat(
                '{"v":1,"question":"',
                question(cell, day),
                '","chainId":4663,"window":{"hours":24},"answerType":"bytes32","evidence":"panel","panelSize":15,"quorum":10,"validForSeconds":86400,"guards":{"sources":["https://api.open-meteo.com"],"minSources":1}}'
            )
        );
    }
}
