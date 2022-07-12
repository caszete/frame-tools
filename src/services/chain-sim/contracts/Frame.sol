//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import './FrameDataStore.sol';
import './FrameDataStoreFactory.sol';


contract Frame {
    struct Asset {
        string assetType;
        string key;
    }

    FrameDataStore public coreDepStorage;
    FrameDataStore public assetStorage;
    
    mapping(uint256 => Asset) public depsList;
    uint256 public depsCount;

    mapping(uint256 => Asset) public assetList;
    uint256 public assetsCount;

    uint256 public renderPagesCount;
    mapping(uint256 => uint256[4]) public renderIndex;

    constructor() {}

    function init(
        address _coreDepStorage,
        address _assetStorage,
        string[2][] calldata _deps,
        string[2][] calldata _assets,
        uint256[4][] calldata _renderIndex
    ) public {
        setCoreDepStorage(FrameDataStore(_coreDepStorage));
        setAssetStorage(FrameDataStore(_assetStorage));
        setDeps(_deps);
        setAssets(_assets);
        setRenderIndex(_renderIndex);
    }

    function setDeps(string[2][] calldata _deps) public {
        for (uint256 dx; dx < _deps.length; dx++) {
            depsList[dx] = Asset({ assetType: _deps[dx][0], key: _deps[dx][1] });
            depsCount++;
        }
    }

    function setAssets(string[2][] calldata _assets) public {
        for (uint256 ax; ax < _assets.length; ax++) {
            assetList[ax] = Asset({ assetType: _assets[ax][0], key: _assets[ax][1] });
            assetsCount++;
        }
    }

    function setCoreDepStorage(FrameDataStore _storage) public {
        coreDepStorage = _storage;
    }

    function setAssetStorage(FrameDataStore _storage) public {
        assetStorage = _storage;
    }

    function setRenderIndex(uint256[4][] calldata _index) public {
        for (uint256 idx; idx < _index.length; idx++) {
            renderPagesCount++;
            renderIndex[idx] = _index[idx];
        }
        renderPagesCount = _index.length;
    }

    function renderWrapper() public view returns (string memory) {
        return string(coreDepStorage.getData("renderWrapper", 0, 0));
    }

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

    function renderPage(uint256 _rpage) public view returns (string memory) {
        // [startAsset, endAsset, startAssetPage, endAssetPage]
        uint256[4] memory indexItem = renderIndex[_rpage];
        uint256 startAtAsset = indexItem[0];
        uint256 endAtAsset = indexItem[1];
        uint256 startAtPage = indexItem[2];
        uint256 endAtPage = indexItem[3];
        string memory result = "";

        for (uint256 idx = startAtAsset; idx < endAtAsset + 1; idx++) {
            bool idxIsDep = idx + 1 <= depsCount;
            uint256 adjustedIdx = idxIsDep ? idx : idx - depsCount;
            FrameDataStore idxStorage = idxIsDep ? coreDepStorage : assetStorage;
            Asset memory idxAsset = idxIsDep ? depsList[idx] : assetList[adjustedIdx];
            string memory storagePointer = idxIsDep ? "coreDepStorage" : "assetStorage";

            uint256 startPage = idx == startAtAsset ? startAtPage : 0;
            uint256 endPage = idx == endAtAsset
                ? endAtPage
                : idxStorage.getMaxPageNumber(idxAsset.key);

            // If starting at zero, include first part of an asset's wrapper
            if (startPage == 0) {
                result = string.concat(
                    result, 
                    string(
                        abi.encodePacked(
                            coreDepStorage.getData(
                                string.concat(idxAsset.assetType, "Wrapper"), 0, 0)
                            )
                        )
                    );
            }

            string memory start = toString(startPage);
            string memory end = toString(endPage);

            result = string.concat(
                result,
                storagePointer,
                idxAsset.key,
                start,
                end
                // abi.encodePacked(
                //     coreDepStorage.getData(idxAsset.key, startPage, endPage)
                // )
            );

            // If needed, include last part of an asset's wrapper
            bool endingEarly = idx == endAtAsset &&
                endAtPage != idxStorage.getMaxPageNumber(idxAsset.key);

            if (!endingEarly) {
                result = string.concat(
                    result, 
                    string(
                        abi.encodePacked(
                            coreDepStorage.getData(
                                string.concat(idxAsset.assetType, "Wrapper"), 1, 1)
                            )
                        )
                    );
            }
        }

        if (_rpage == 0) {
            result = string.concat(string(coreDepStorage.getData("renderWrapper", 0, 0)), result);
        }
        
        if (_rpage == (renderPagesCount - 1)) {
            result = string.concat(result, string(coreDepStorage.getData("renderWrapper", 1, 1)));
        }

        return result;
    }
}