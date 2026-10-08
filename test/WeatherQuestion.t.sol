// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {WeatherQuestion} from "../src/WeatherQuestion.sol";

contract WeatherQuestionTest is Test {
    function test_exactLisbonBodyAndKnownDate() public pure {
        bytes memory expected = bytes(
            '{"v":1,"question":"weather at latitude 38.875 longitude -9.125 on 2024-10-04 utc, from https://api.open-meteo.com/v1/forecast?latitude=38.875&longitude=-9.125&past_days=92&hourly=is_day,cloud_cover,precipitation&timezone=UTC, the 24 rows of 2024-10-04. hour h (0..23) is SUNNY if is_day=1 and cloud_cover<50 and precipitation=0; RAINY if precipitation>=0.2. answer one bytes32 = sunMask | rainMask<<24 | complete<<48 | 20000<<96, bit h of each mask = hour h; complete = 1 if all 24 rows have values, else 0 with masks 0.","chainId":4663,"window":{"hours":24},"answerType":"bytes32","evidence":"panel","panelSize":15,"quorum":10,"validForSeconds":86400,"guards":{"sources":["https://api.open-meteo.com"],"minSources":1}}'
        );
        assertEq(WeatherQuestion.body(10223579, 20000), expected);
    }

    function test_exactNegativeLatitudeAndLongitudeBody() public pure {
        bytes memory expected = bytes(
            '{"v":1,"question":"weather at latitude -33.625 longitude -58.625 on 2000-02-29 utc, from https://api.open-meteo.com/v1/forecast?latitude=-33.625&longitude=-58.625&past_days=92&hourly=is_day,cloud_cover,precipitation&timezone=UTC, the 24 rows of 2000-02-29. hour h (0..23) is SUNNY if is_day=1 and cloud_cover<50 and precipitation=0; RAINY if precipitation>=0.2. answer one bytes32 = sunMask | rainMask<<24 | complete<<48 | 11016<<96, bit h of each mask = hour h; complete = 1 if all 24 rows have values, else 0 with masks 0.","chainId":4663,"window":{"hours":24},"answerType":"bytes32","evidence":"panel","panelSize":15,"quorum":10,"validForSeconds":86400,"guards":{"sources":["https://api.open-meteo.com"],"minSources":1}}'
        );
        uint32 cell = uint32(uint16(int16(-135))) << 16 | uint16(int16(-235));
        assertEq(WeatherQuestion.body(cell, 11016), expected);
    }

    function test_coordinatesAtEdgesAndNegativeZeroFraction() public pure {
        assertEq(WeatherQuestion.coordinate(-1), "-0.125");
        assertEq(WeatherQuestion.coordinate(0), "0.125");
        assertEq(WeatherQuestion.coordinate(-360), "-89.875");
        assertEq(WeatherQuestion.coordinate(359), "89.875");
        assertEq(WeatherQuestion.coordinate(-720), "-179.875");
        assertEq(WeatherQuestion.coordinate(719), "179.875");
        assertEq(WeatherQuestion.date(0), "1970-01-01");
        assertEq(WeatherQuestion.date(11017), "2000-03-01");
        assertEq(WeatherQuestion.date(47540), "2100-02-28");
        assertEq(WeatherQuestion.date(47541), "2100-03-01");
        assertEq(WeatherQuestion.date(2932896), "9999-12-31");
    }
}
