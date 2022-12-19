// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "./IRoomShare.sol";


contract RoomShare is IRoomShare{

  mapping(uint => Room) public roomId2room;
  mapping(address => Rent[]) public renter2rent;
  mapping(uint => Rent[]) public roomId2rent;
  uint public roomId = 0;
  uint public rentId = 0;


  function getAllRooms() external view returns(Room[] memory){
    Room[] memory tempRoomList = new Room[](roomId);
    for(uint i = 0; i<roomId; i++){
      tempRoomList[i] = roomId2room[i];
    }
    return tempRoomList;
  }

  function getMyRents() external view override returns(Rent[] memory) {
    /* 함수를 호출한 유저의 대여 목록을 가져온다. */
    return renter2rent[msg.sender];
  }

  function getRoomRentHistory(uint _roomId) external view override returns(Rent[] memory) {
    /* 특정 방의 대여 히스토리를 보여준다. */
    return roomId2rent[_roomId];
  }

  function shareRoom( string calldata name, 
                      string calldata location, 
                      uint price ) public override {
    /**
     * 1. isActive 초기값은 true로 활성화, 함수를 호출한 유저가 방의 소유자이며, 365 크기의 boolean 배열을 생성하여 방 객체를 만든다.
     * 2. 방의 id와 방 객체를 매핑한다.
     */
    bool[] memory rentHistory = new bool[](365);
    for(uint i=0; i<365; i++){
      rentHistory[i] = false;
    }
    Room memory room = Room(roomId, name, location, true, price, msg.sender, rentHistory);
    roomId2room[roomId] = room;
    
    emit NewRoom(roomId++);
    }

  

  function _createRent(uint256 _roomId, uint year, uint256 checkInDate, uint256 checkOutDate) public override {
    /**
     * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
     * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
     * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
     */

    Rent memory rent = Rent(rentId, _roomId, year, checkInDate, checkOutDate, msg.sender);
    for(uint i=checkInDate;i<checkOutDate;i++){
      roomId2room[_roomId].isRented[i] = true;
    }
    renter2rent[msg.sender].push(rent);
    roomId2rent[_roomId].push(rent);
    emit NewRent(_roomId, rentId++);
  }

  function _sendFunds (address owner, uint256 value) public override{
      payable(owner).transfer(value);
  }
  

  function getIsActive(uint _roomId) view external returns(bool){
      return roomId2room[_roomId].isActive;
  }

  function getIsInvalidValue(uint value) view external returns(bool){
      return value > (msg.sender.balance / 1000000000000000);
  }

  function getIsAlreadyReservation(uint _roomId, uint checkInDate, uint checkOutDate) view external returns(bool){
    bool valid = false;
    for(uint i=checkInDate;i<checkOutDate;i++){
        if(roomId2room[_roomId].isRented[i]){
          valid = true;
        }
      }
    return valid;
  }


  function rentRoom(uint _roomId, uint year, uint checkInDate, uint checkOutDate) payable external override {
    /**
     * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
     *    a. 현재 활성화(isActive) 되어 있는지
     *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지 
     *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei) 
     * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
     * *** 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***
     */
    require(roomId2room[_roomId].isActive, "NotActive");
    uint valid = 1;
    for(uint i=checkInDate;i<checkOutDate;i++){
        if(roomId2room[_roomId].isRented[i]){
          valid = 0;
        }
      }
    require(valid == 1, "AlreadyReservation");
    require(msg.value <= (msg.sender.balance / 1000000000000000), "NotValidValue");
    _sendFunds(roomId2room[_roomId].owner, msg.value);
    _createRent(_roomId, year, checkInDate, checkOutDate);
  }

  function recommendDate(uint _roomId, uint checkInDate, uint checkOutDate) external view override returns(uint256[] memory)  {
    /**
     * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우, 
     * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
     * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
     */
    uint256[] memory dates = new uint[](2);

    for(uint i=0;i<roomId2rent[_roomId].length;i++){
      if(roomId2rent[_roomId][i].checkInDate < dates[0]){
        if(roomId2rent[_roomId][i].checkInDate <= checkInDate || roomId2rent[_roomId][i].checkOutDate <= checkOutDate){
          dates[0] = roomId2rent[_roomId][i].checkInDate;
          dates[1] = roomId2rent[_roomId][i].checkOutDate;
          break;
        }
      }
      else{
        if(roomId2rent[_roomId][i].checkInDate <= checkInDate || roomId2rent[_roomId][i].checkOutDate <= checkOutDate){
          dates[0] = roomId2rent[_roomId][i].checkInDate;
          dates[1] = roomId2rent[_roomId][i].checkOutDate;
          break;
        }
      }
    }
    return dates;
  }

  function markRoomAsInactive(uint _roomId) external override{
    if(roomId2room[_roomId].owner == msg.sender){
      roomId2room[_roomId].isActive = false;
    }
  }

  function initializeRoomShare(uint _roomId) external override{
    for(uint i=0; i<365; i++){
      roomId2room[_roomId].isRented[i] = false;
    } 
  }

}
