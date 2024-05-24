// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./CircularListManager.sol";
import "../../userInterfaces/IIncreaseManager.sol";
import "../lib/FixedPointArithmetic.sol" as FPA;

abstract contract IncreaseManager is IIncreaseManager, CircularListManager {
    // Circular lists all
    FPA.SampleSize[] internal sampleIncreases;
    FPA.Range[] internal rangeIncreases;
    FPA.Fee[] internal excessOfferIncreases;

    FPA.SampleSize internal sampleSize;
    FPA.Range internal range;
    FPA.Fee internal excessOfferValue;

    constructor(FPA.SampleSize _ss, FPA.Range _r, FPA.Fee _x, uint256 _dur) CircularListManager(_dur) {
        _updateSettings(_ss, _r, _x, _dur);
    }

    function getIncentiveDuration() external view returns (uint256) {
        return circularLength;
    }

    function _step() internal {
        // Bookkeeping for the cached values
        excessOfferValue = FPA.sub(excessOfferValue, excessOfferIncreases[_nextIx()]);
        range = FPA.sub(range, rangeIncreases[_nextIx()]);
        sampleSize = FPA.sub(sampleSize, sampleIncreases[_nextIx()]);
        sampleIncreases[_nextIx()] = FPA.zeroS;
        rangeIncreases[_nextIx()] = FPA.zeroR;
        excessOfferIncreases[_nextIx()] = FPA.zeroF;
    }

    function _increaseSampleSize(FPA.SampleSize _de) internal {
        sampleIncreases[_thisIx()] = FPA.add(sampleIncreases[_thisIx()], _de);
        sampleSize = FPA.add(sampleSize, _de);
        require(FPA.check(sampleSize), "Sample size too large");
    }

    function _increaseRange(FPA.Range _dr) internal {
        rangeIncreases[_thisIx()] = FPA.add(rangeIncreases[_thisIx()], _dr);
        range = FPA.add(range, _dr);
        require(FPA.check(range), "Range too large");
    }

    function _increaseExcessOfferValue(FPA.Fee _dx) internal {
        excessOfferIncreases[_thisIx()] = FPA.add(excessOfferIncreases[_thisIx()], _dx);
        excessOfferValue = FPA.add(excessOfferValue, _dx);
        require(FPA.check(excessOfferValue), "Excess offer value too large");
    }

    function _updateSettings(FPA.SampleSize _ss, FPA.Range _r, FPA.Fee _x, uint256 _dur) internal {
        _setSampleSize(_ss);
        _setRange(_r);
        require(FPA.lessThan(_r, _ss), "Range must be less than sample size");
        // since feeds are 32 bit values, the precision of updates needs to be bounded
        require((FPA.Precision.unwrap(FPA.div(_r, _ss)) >> (127 - 25)) > 0,
            "Precision value of updates needs to be at least 2^(-25)");
        _setExcessOfferValue(_x);
        _setCircularLength(_dur);
        _init();
    }

    function _setSampleSize(FPA.SampleSize _ss) private {
        require(FPA.check(_ss), "Sample size too large");
        sampleSize = _ss;
    }

    function _setRange(FPA.Range _r) private {
        require(FPA.check(_r), "Range too large");
        range = _r;
    }

    function _setExcessOfferValue(FPA.Fee _x) private {
        require(FPA.check(_x), "Excess offer value too large");
        excessOfferValue = _x;
    }

    function _init() private {
        delete sampleIncreases;
        delete rangeIncreases;
        delete excessOfferIncreases;

        sampleIncreases = new FPA.SampleSize[](circularLength);
        rangeIncreases = new FPA.Range[](circularLength);
        excessOfferIncreases = new FPA.Fee[](circularLength);
    }
}
