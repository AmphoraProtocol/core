// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import {IAmphoraProtocolToken} from '@interfaces/governance/IAmphoraProtocolToken.sol';
import {Context} from '@openzeppelin/contracts/utils/Context.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract AmphoraProtocolToken is IAmphoraProtocolToken, Context, Ownable {
  /// @notice The EIP-712 typehash for the contract's domain
  bytes32 public constant DOMAIN_TYPEHASH =
    keccak256('EIP712Domain(string name,uint256 chainId,address verifyingContract)');

  /// @dev The EIP-712 typehash for the delegation struct used by the contract
  bytes32 public constant DELEGATION_TYPEHASH = keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

  /// @dev The EIP-712 typehash for the permit struct used by the contract
  bytes32 public constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  uint96 public constant UINT96_MAX = 2 ** 96 - 1;

  uint256 public constant UINT256_MAX = 2 ** 256 - 1;

  /// @dev The token decimals for this token
  uint8 public constant decimals = 18;

  /// @dev The token name for this token
  string public name = 'Amphora Protocol';

  /// @dev The token symbol for this token
  string public symbol = 'AMPH';

  /// @dev Total number of tokens in circulation
  uint256 public totalSupply;

  /// @dev Allowance amounts on behalf of others
  mapping(address => mapping(address => uint96)) internal _allowances;

  /// @dev Official record of token balances for each account
  mapping(address => uint96) internal _balances;

  /// @dev A record of each accounts delegate
  mapping(address => address) public delegates;

  /// @dev A record of votes checkpoints for each account, by index
  mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

  /// @dev The number of checkpoints for each account
  mapping(address => uint32) public numCheckpoints;

  /// @dev A record of states for signing / validating signatures
  mapping(address => uint256) public nonces;

  /// @notice Used to initialize the contract during delegator constructor
  /// @param _account The address to recieve initial suppply
  /// @param _initialSupply The initial supply
  function initialize(address _account, uint256 _initialSupply) public override {
    if (totalSupply != 0) revert TokenDelegate_AlreadyInitialized();
    if (_account == address(0)) revert TokenDelegate_InvalidAddress();
    if (_initialSupply <= 0) revert TokenDelegate_InvalidSupply();

    totalSupply = _initialSupply;

    if (_initialSupply >= 2 ** 96) revert TokenDelegate_Overflow();

    _balances[_account] = uint96(totalSupply);
    emit Transfer(address(0), _account, totalSupply);
  }

  /// @notice Change token name
  /// @param _name New token name
  function changeName(string calldata _name) external override onlyOwner {
    if (bytes(_name).length <= 0) revert TokenDelegate_InvalidLength();

    emit ChangedName(name, _name);

    name = _name;
  }

  /// @notice Change token symbol
  /// @param _symbol New token symbol
  function changeSymbol(string calldata _symbol) external override onlyOwner {
    if (bytes(_symbol).length <= 0) revert TokenDelegate_InvalidLength();

    emit ChangedSymbol(symbol, _symbol);

    symbol = _symbol;
  }

  /// @notice Returns the number of tokens `spender` is approved to spend on behalf of `account`
  /// @param _account The address of the account holding the funds
  /// @param _spender The address of the account spending the funds
  /// @return _approvedTokens The number of tokens approved
  function allowance(address _account, address _spender) external view override returns (uint256 _approvedTokens) {
    return _allowances[_account][_spender];
  }

  /// @notice Approve `spender` to transfer up to `amount` from `src`
  /// @dev This will overwrite the approval amount for `spender`
  ///      and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
  /// @param _spender The address of the account which may transfer tokens
  /// @param _rawAmount The number of tokens that are approved (2^256-1 means infinite)
  /// @return _succeeded Whether or not the approval succeeded
  function approve(address _spender, uint256 _rawAmount) external override returns (bool _succeeded) {
    uint96 _amount;
    if (_rawAmount == UINT256_MAX) _amount = UINT96_MAX;
    else _amount = _safe96(_rawAmount, 'approve: amount exceeds 96 bits');

    _allowances[msg.sender][_spender] = _amount;

    emit Approval(msg.sender, _spender, _amount);
    return true;
  }

  /// @notice Triggers an approval from owner to spends
  /// @param _owner The address to approve from
  /// @param _spender The address to be approved
  /// @param _rawAmount The number of tokens that are approved (2^256-1 means infinite)
  /// @param _deadline The time at which to expire the signature
  /// @param _v The recovery byte of the signature
  /// @param _r Half of the ECDSA signature pair
  /// @param _s Half of the ECDSA signature pair
  function permit(
    address _owner,
    address _spender,
    uint256 _rawAmount,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external override {
    uint96 _amount;
    if (_rawAmount == UINT256_MAX) _amount = UINT96_MAX;
    else _amount = _safe96(_rawAmount, 'permit: amount exceeds 96 bits');

    bytes32 _domainSeparator =
      keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), _getChainId(), address(this)));
    bytes32 _structHash =
      keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _rawAmount, nonces[_owner]++, _deadline));
    bytes32 _digest = keccak256(abi.encodePacked('\x19\x01', _domainSeparator, _structHash));
    if (uint256(_s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
      revert TokenDelegate_InvalidSignature();
    }
    address _signatory = ecrecover(_digest, _v, _r, _s);
    if (_signatory == address(0x0)) revert TokenDelegate_InvalidSignature();

    if (block.timestamp > _deadline) revert TokenDelegate_SignatureExpired();

    _allowances[_owner][_spender] = _amount;

    emit Approval(_owner, _spender, _amount);
  }

  /// @notice Get the number of tokens held by the `account`
  /// @param _account The address of the account to get the balance of
  /// @return _balance The number of tokens held
  function balanceOf(address _account) external view override returns (uint256 _balance) {
    return _balances[_account];
  }

  /// @notice Transfer `amount` tokens from `msg.sender` to `dst`
  /// @param _dst The address of the destination account
  /// @param _rawAmount The number of tokens to transfer
  /// @return _succeeded Whether or not the transfer succeeded
  function transfer(address _dst, uint256 _rawAmount) external override returns (bool _succeeded) {
    uint96 _amount = _safe96(_rawAmount, 'transfer: amount exceeds 96 bits');
    _transferTokens(msg.sender, _dst, _amount);
    return true;
  }

  /// @notice Transfer `amount` tokens from `src` to `dst`
  /// @param _src The address of the source account
  /// @param _dst The address of the destination account
  /// @param _rawAmount The number of tokens to transfer
  /// @return _succeeded Whether or not the transfer succeeded
  function transferFrom(address _src, address _dst, uint256 _rawAmount) external override returns (bool _succeeded) {
    address _spender = msg.sender;
    uint96 _spenderAllowance = _allowances[_src][_spender];
    uint96 _amount = _safe96(_rawAmount, 'transferFrom: amount exceeds 96 bits');

    if (_spender != _src && _spenderAllowance != UINT96_MAX) {
      uint96 _newAllowance =
        _sub96(_spenderAllowance, _amount, 'transferFrom: transfer amount exceeds spender allowance');
      _allowances[_src][_spender] = _newAllowance;

      emit Approval(_src, _spender, _newAllowance);
    }

    _transferTokens(_src, _dst, _amount);
    return true;
  }

  /// @notice Mint new tokens
  /// @param _dst The address of the destination account
  /// @param _rawAmount The number of tokens to be minted
  function mint(address _dst, uint256 _rawAmount) external override onlyOwner {
    require(_dst != address(0), 'mint: cant transfer to 0 address');
    uint96 _amount = _safe96(_rawAmount, 'mint: amount exceeds 96 bits');
    totalSupply = _safe96(totalSupply + _amount, 'mint: totalSupply exceeds 96 bits');

    // transfer the amount to the recipient
    _balances[_dst] = _add96(_balances[_dst], _amount, 'mint: transfer amount overflows');
    emit Transfer(address(0), _dst, _amount);

    // move delegates
    _moveDelegates(address(0), delegates[_dst], _amount);
  }

  /// @notice Delegate votes from `msg.sender` to `delegatee`
  /// @param _delegatee The address to delegate votes to
  function delegate(address _delegatee) public override {
    return _delegate(msg.sender, _delegatee);
  }

  /// @notice Delegates votes from signatory to `delegatee`
  /// @param _delegatee The address to delegate votes to
  /// @param _nonce The contract state required to match the signature
  /// @param _expiry The time at which to expire the signature
  /// @param _v The recovery byte of the signature
  /// @param _r Half of the ECDSA signature pair
  /// @param _s Half of the ECDSA signature pair
  function delegateBySig(
    address _delegatee,
    uint256 _nonce,
    uint256 _expiry,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) public override {
    bytes32 _domainSeparator =
      keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), _getChainId(), address(this)));
    bytes32 _structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, _delegatee, _nonce, _expiry));
    bytes32 _digest = keccak256(abi.encodePacked('\x19\x01', _domainSeparator, _structHash));
    if (uint256(_s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
      revert TokenDelegate_InvalidSignature();
    }
    address _signatory = ecrecover(_digest, _v, _r, _s);
    if (_signatory == address(0)) revert TokenDelegate_InvalidSignature();

    if (_nonce != nonces[_signatory]++) revert TokenDelegate_InvalidNonce();
    if (block.timestamp > _expiry) revert TokenDelegate_SignatureExpired();
    return _delegate(_signatory, _delegatee);
  }

  /// @notice Returns the current votes balance for `account`
  /// @param _account The address to get votes balance
  /// @return _votes The number of current votes for `account`
  function getCurrentVotes(address _account) external view override returns (uint96 _votes) {
    uint32 _nCheckpoints = numCheckpoints[_account];
    return _nCheckpoints > 0 ? checkpoints[_account][_nCheckpoints - 1].votes : 0;
  }

  /// @notice Determine the prior number of votes for an account as of a block number
  /// @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
  /// @param _account The address of the account to check
  /// @param _blockNumber The block number to get the vote balance at
  /// @return _accountVotes The number of votes the account had as of the given block
  function getPriorVotes(address _account, uint256 _blockNumber) public view override returns (uint96 _accountVotes) {
    if (_blockNumber >= block.number) revert TokenDelegate_CannotDetermineVotes();
    // check naive cases
    (bool _ok, uint96 _votes) = _naivePriorVotes(_account, _blockNumber);
    if (_ok) return _votes;
    uint32 _lower;
    uint32 _upper = numCheckpoints[_account] - 1;
    while (_upper > _lower) {
      uint32 _center = _upper - (_upper - _lower) / 2; // ceil, avoiding overflow
      Checkpoint memory _cp = checkpoints[_account][_center];
      (_ok, _lower, _upper) = _binarySearch(_cp.fromBlock, _blockNumber, _lower, _upper);
      if (_ok) return _cp.votes;
    }
    return checkpoints[_account][_lower].votes;
  }

  /// @notice Naive cases to check for votes
  /// @param _account The account to check
  /// @param _blockNumber The block number to check
  function _naivePriorVotes(address _account, uint256 _blockNumber) internal view returns (bool _ok, uint96 _ans) {
    uint32 _nCheckpoints = numCheckpoints[_account];
    // if no checkpoints, must be 0
    if (_nCheckpoints == 0) return (true, 0);
    // First check most recent balance
    if (checkpoints[_account][_nCheckpoints - 1].fromBlock <= _blockNumber) {
      return (true, checkpoints[_account][_nCheckpoints - 1].votes);
    }
    // Next check implicit zero balance
    if (checkpoints[_account][0].fromBlock > _blockNumber) return (true, 0);
    return (false, 0);
  }

  /// @notice Binary search
  /// @param _from The block number to start searching from
  /// @param _blk The block number to search for
  /// @param _lower The lower bound of the search
  /// @param _upper The upper bound of the search
  function _binarySearch(
    uint32 _from,
    uint256 _blk,
    uint32 _lower,
    uint32 _upper
  ) internal pure returns (bool _ok, uint32 _newLower, uint32 _newUpper) {
    uint32 _center = _upper - (_upper - _lower) / 2; // ceil, avoiding overflow
    if (_from == _blk) return (true, 0, 0);
    if (_from < _blk) return (false, _center, _upper);
    return (false, _lower, _center - 1);
  }

  /// @notice Assign delegate to another address
  /// @param _delegator The address to change delegate
  /// @param _delegatee The address to delegate to
  function _delegate(address _delegator, address _delegatee) internal {
    address _currentDelegate = delegates[_delegator];
    uint96 _delegatorBalance = _balances[_delegator];
    delegates[_delegator] = _delegatee;

    emit DelegateChanged(_delegator, _currentDelegate, _delegatee);

    _moveDelegates(_currentDelegate, _delegatee, _delegatorBalance);
  }

  /// @notice Transfer tokens
  /// @param _src The address to transfer from
  /// @param _dst The address to transfer to
  /// @param _amount The amount to transfer
  function _transferTokens(address _src, address _dst, uint96 _amount) internal {
    if (_src == address(0) || _dst == address(0)) revert TokenDelegate_ZeroAddress();

    _balances[_src] = _sub96(_balances[_src], _amount, '_transferTokens: transfer amount exceeds balance');
    _balances[_dst] = _add96(_balances[_dst], _amount, '_transferTokens: transfer amount overflows');
    emit Transfer(_src, _dst, _amount);

    _moveDelegates(delegates[_src], delegates[_dst], _amount);
  }

  /// @notice Move delegates to another address
  /// @param _srcRep The address to move from
  /// @param _dstRep The address to move to
  /// @param _amount The amount to move
  function _moveDelegates(address _srcRep, address _dstRep, uint96 _amount) internal {
    if (_srcRep != _dstRep && _amount > 0) {
      if (_srcRep != address(0)) {
        uint32 _srcRepNum = numCheckpoints[_srcRep];
        uint96 _srcRepOld = _srcRepNum > 0 ? checkpoints[_srcRep][_srcRepNum - 1].votes : 0;
        uint96 _srcRepNew = _sub96(_srcRepOld, _amount, '_moveVotes: vote amt underflows');
        _writeCheckpoint(_srcRep, _srcRepNum, _srcRepOld, _srcRepNew);
      }

      if (_dstRep != address(0)) {
        uint32 _dstRepNum = numCheckpoints[_dstRep];
        uint96 _dstRepOld = _dstRepNum > 0 ? checkpoints[_dstRep][_dstRepNum - 1].votes : 0;
        uint96 _dstRepNew = _add96(_dstRepOld, _amount, '_moveVotes: vote amt overflows');
        _writeCheckpoint(_dstRep, _dstRepNum, _dstRepOld, _dstRepNew);
      }
    }
  }

  /// @notice Write checkpoint
  /// @param _delegatee The address to write checkpoint for
  /// @param _nCheckpoints The number of checkpoints
  /// @param _oldVotes The old votes
  /// @param _newVotes The new votes
  function _writeCheckpoint(address _delegatee, uint32 _nCheckpoints, uint96 _oldVotes, uint96 _newVotes) internal {
    uint32 _blockNumber = _safe32(block.number, '_writeCheckpoint: blocknum exceeds 32 bits');

    if (_nCheckpoints > 0 && checkpoints[_delegatee][_nCheckpoints - 1].fromBlock == _blockNumber) {
      checkpoints[_delegatee][_nCheckpoints - 1].votes = _newVotes;
    } else {
      checkpoints[_delegatee][_nCheckpoints] = Checkpoint(_blockNumber, _newVotes);
      numCheckpoints[_delegatee] = _nCheckpoints + 1;
    }

    emit DelegateVotesChanged(_delegatee, _oldVotes, _newVotes);
  }

  /// @notice Safe uint32
  /// @param _n The number to convert
  /// @param _errorMessage The error message to revert with
  /// @return _ans The converted number
  function _safe32(uint256 _n, string memory _errorMessage) internal pure returns (uint32 _ans) {
    require(_n < 2 ** 32, _errorMessage);
    return uint32(_n);
  }

  /// @notice Safe uint96
  /// @param _n The number to convert
  /// @param _errorMessage The error message to revert with
  /// @return _ans The converted number
  function _safe96(uint256 _n, string memory _errorMessage) internal pure returns (uint96 _ans) {
    require(_n < 2 ** 96, _errorMessage);
    return uint96(_n);
  }

  /// @notice Safe add uint96
  /// @param _a The first number
  /// @param _b The second number
  /// @param _errorMessage The error message to revert with
  /// @return _c The resulting sum
  function _add96(uint96 _a, uint96 _b, string memory _errorMessage) internal pure returns (uint96 _c) {
    _c = _a + _b;
    require(_c >= _a, _errorMessage);
    return _c;
  }

  /// @notice Safe sub uint96
  /// @param _a The first number
  /// @param _b The second number
  /// @param _errorMessage The error message to revert with
  /// @return _c The resulting difference
  function _sub96(uint96 _a, uint96 _b, string memory _errorMessage) internal pure returns (uint96 _c) {
    require(_b <= _a, _errorMessage);
    return _a - _b;
  }

  /// @notice Returns the current chain id
  /// @return _chainId The current chain id
  function _getChainId() internal view returns (uint256 _chainId) {
    //solhint-disable-next-line no-inline-assembly
    assembly {
      _chainId := chainid()
    }
    return _chainId;
  }
}
