//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract FrameDataStore {
    struct ContractData {
        address rawContract;
        uint128 size;
        uint128 offset;
    }

    struct ContractDataPages {
        uint256 maxPageNumber;
        bool exists;
        mapping(uint256 => ContractData) pages;
    }

    mapping(string => ContractDataPages) internal _contractDataPages;

    mapping(address => bool) internal _controllers;

    constructor() {}

    function saveData(
        string memory _key,
        uint128 _pageNumber,
        bytes memory _b
    ) public {
        require(
            _b.length < 24576,
            "Storage: Exceeded 24,576 bytes max contract size"
        );

        // Create the header for the contract data
        bytes memory init = hex"610000_600e_6000_39_610000_6000_f3";
        bytes1 size1 = bytes1(uint8(_b.length));
        bytes1 size2 = bytes1(uint8(_b.length >> 8));
        init[2] = size1;
        init[1] = size2;
        init[10] = size1;
        init[9] = size2;

        // Prepare the code for storage in a contract
        bytes memory code = abi.encodePacked(init, _b);

        // Create the contract
        address dataContract;
        assembly {
            dataContract := create(0, add(code, 32), mload(code))
            if eq(dataContract, 0) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        // Store the record of the contract
        saveDataForDeployedContract(
            _key,
            _pageNumber,
            dataContract,
            uint128(_b.length),
            0
        );
    }

    function saveDataForDeployedContract(
        string memory _key,
        uint256 _pageNumber,
        address dataContract,
        uint128 _size,
        uint128 _offset
    ) public {
        // Pull the current data for the contractData
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Store the maximum page
        if (_cdPages.maxPageNumber < _pageNumber) {
            _cdPages.maxPageNumber = _pageNumber;
        }

        // Keep track of the existance of this key
        _cdPages.exists = true;

        // Add the page to the location needed
        _cdPages.pages[_pageNumber] = ContractData(
            dataContract,
            _size,
            _offset
        );
    }

    function getSizeOfPages(string memory _key) public view returns (uint256) {
        // For all data within the contract data pages, iterate over and compile them
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Determine the total size
        uint256 totalSize;
        for (uint256 idx; idx <= _cdPages.maxPageNumber; idx++) {
            totalSize += _cdPages.pages[idx].size;
        }

        return totalSize;
    }

    function getSizeUpToPage(string memory _key, uint256 _endPage)
        public
        view
        returns (uint256)
    {
        // For all data within the contract data pages, iterate over and compile them
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Determine the total size
        uint256 totalSize;
        for (uint256 idx; idx <= _endPage; idx++) {
            totalSize += _cdPages.pages[idx].size;
        }

        return totalSize;
    }

    function getSizeBetweenPages(
        string memory _key,
        uint256 _startPage,
        uint256 _endPage
    ) public view returns (uint256) {
        // For all data within the contract data pages, iterate over and compile them
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // Determine the total size
        uint256 totalSize;
        for (uint256 idx = _startPage; idx <= _endPage; idx++) {
            totalSize += _cdPages.pages[idx].size;
        }

        return totalSize;
    }

    function getMaxPageNumber(string memory _key)
        public
        view
        returns (uint256)
    {
        return _contractDataPages[_key].maxPageNumber;
    }

    // _endPage < 0 goes to the last page
    function getData(
        string memory _key,
        uint256 _startPage,
        uint256 _endPage
    ) public view returns (bytes memory) {
        // bool endPageNeg = _endPage < 0;

        // Get the total size
        // uint256 totalSize = endPageNeg
        //     ? getSizeBetweenPages(_key, _startPage, _endPage)
        //     : getSizeOfPages(_key);

        uint256 totalSize = getSizeBetweenPages(_key, _startPage, _endPage);

        // Create a region large enough for all of the data
        bytes memory _totalData = new bytes(totalSize);

        // Retrieve the pages
        ContractDataPages storage _cdPages = _contractDataPages[_key];

        // uint256 endPageNumber = endPageNeg
        //     ? _endPage
        //     : _cdPages.maxPageNumber;

        // For each page, pull and compile
        uint256 currentPointer = 32;
        for (uint256 idx = _startPage; idx <= _endPage; idx++) {
            ContractData storage dataPage = _cdPages.pages[idx];
            address dataContract = dataPage.rawContract;
            uint256 size = uint256(dataPage.size);
            uint256 offset = uint256(dataPage.offset);

            // Copy directly to total data
            assembly {
                extcodecopy(
                    dataContract,
                    add(_totalData, currentPointer),
                    offset,
                    size
                )
            }

            // Update the current pointer
            currentPointer += size;
        }

        return _totalData;
    }

    function getAllDataFrom(
        string memory _key,
        uint256 _startPage
    ) public view returns (bytes memory) {
        ContractDataPages storage _cdPages = _contractDataPages[_key];
        return getData(_key, _startPage, _cdPages.maxPageNumber);
    }
}