// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library AddressSet {
    struct State {
        address[] list;
        mapping (address => uint256) index;
    }

    function add(State storage _state, address _address) internal {
        if (_state.index[_address] != 0) return;
        _state.list.push(_address);
        _state.index[_address] = _state.list.length;
    }

    function remove(State storage _state, address _address) internal {
        uint256 position = _state.index[_address];
        if (position == 0) return;
        if (position < _state.list.length) {
            address addressToMove = _state.list[_state.list.length - 1];
            _state.list[position - 1] = addressToMove;
            _state.index[addressToMove] = position;
        }
        _state.list.pop();
        delete _state.index[_address];
    }

    function replace(State storage _state, address _addressToRemove, address _addressToAdd) internal {
        if (_addressToRemove == _addressToAdd) {
            return;
        }
        uint256 position = _state.index[_addressToRemove];
        if (position == 0) {
            add(_state, _addressToAdd);
            return;
        }
        if (_state.index[_addressToAdd] != 0) {
            remove(_state, _addressToRemove);
            return;
        }
        _state.list[position - 1] = _addressToAdd;
        _state.index[_addressToAdd] = position;
        delete _state.index[_addressToRemove];
    }

    function addAll(State storage _state, address[] memory _addresses) internal {
        for (uint256 i = 0; i < _addresses.length; i++) {
            add(_state, _addresses[i]);
        }
    }

    function replaceAll(State storage _state, address[] memory _addresses) internal {
        clear(_state);
        addAll(_state, _addresses);
    }

    function clear(State storage _state) internal {
        while (_state.list.length > 0) {
            delete _state.index[_state.list[_state.list.length - 1]];
            _state.list.pop();
        }
    }
}
