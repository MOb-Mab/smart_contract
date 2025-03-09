
## การทำงานทั่วไป

ใช้กลไก commit-reveal เพื่อให้ผู้เล่นไม่รู้ตัวเลือกของฝ่ายตรงข้าม โดยมีขั้นตอนหลักๆ ดังนี้:
1. ผู้เล่นสองคนเข้าร่วมเกมด้วยการวางเงิน 1 ether 
2. ผู้เล่นแต่ละคนส่ง commit ของตัวเลือก (0-4)
3. ผู้เล่นเปิดเผย (reveal) ตัวเลือกที่แท้จริง
4. สัญญาตรวจสอบผู้ชนะและจ่ายเงินรางวัล

## ส่วนที่ป้องกันการ lock เงินไว้ใน contract



1. **ฟังก์ชัน refund()**:

function refund() public {
    require(numPlayer == 1 && timeUnit.elapsedSeconds() > TIMEOUT_SECONDS, "Refund not available");
    
    payable(players[0]).transfer(reward);
    _resetGame();
}

ฟังก์ชันนี้อนุญาตให้ผู้เล่นคนแรกขอเงินคืนได้หากไม่มีผู้เล่นคนที่สองเข้าร่วมภายในเวลาที่กำหนด (300 วินาที) ซึ่งจะคืนเงินทั้งหมดให้กับผู้เล่นคนแรกและรีเซ็ตเกม

2. **ฟังก์ชัน forceEndGame()**:
function forceEndGame() public {
    require(numPlayer == 2, "Game not started");
    require(timeUnit.elapsedSeconds() > TIMEOUT_SECONDS, "Timeout not reached");

    if (player_commit[players[0]] == bytes32(0) || player_commit[players[1]] == bytes32(0)) {
        _refundBothplayer();
    } else if (!hasRevealed[players[0]] || !hasRevealed[players[1]]) {
        _refundBothplayer();
    } else {
        _checkWinnerAndPay();
    }
    _resetGame();
}

ฟังก์ชันนี้สามารถเรียกได้หลังจากหมดเวลาที่กำหนด (300 วินาที) และจะจัดการในกรณีต่างๆ:
- ถ้าผู้เล่นคนใดคนหนึ่งไม่ได้ commit: คืนเงินให้ทั้งสองคนเท่าๆ กัน
- ถ้าผู้เล่นคนใดคนหนึ่งไม่ได้ reveal: คืนเงินให้ทั้งสองคนเท่าๆ กัน
- ถ้าทั้งสองคน reveal แล้ว: ตรวจสอบผู้ชนะและจ่ายเงิน

3. **ฟังก์ชัน _refundBothplayer()**:
function _refundBothplayer() private {
    payable(players[0]).transfer(reward / 2);
    payable(players[1]).transfer(reward / 2);
}

ฟังก์ชันนี้แบ่งเงินรางวัลให้กับผู้เล่นทั้งสองเท่าๆ กัน ซึ่งจะถูกเรียกในกรณีที่ผู้เล่นเสมอกันหรือมีการยกเลิกเกม

## ส่วนที่ทำการซ่อน choice และ commit

1. **ฟังก์ชัน commitChoice()**:

function commitChoice(bytes32 hashedData) public {
    require(numPlayer == 2, "Not enough players");
    require(player_commit[msg.sender] == bytes32(0), "Already committed");
    require(msg.sender == players[0] || msg.sender == players[1], "You are not in this round");
    
    player_commit[msg.sender] = hashedData;
    commitreveal.commit(hashedData);
    numInput++;
    
    if (numInput == 2) {
        timeUnit.setStartTime(); 
    }
}

ฟังก์ชันนี้รับค่า hash (bytes32) ที่ผู้เล่นส่งมา ซึ่งควรเป็น hash ของตัวเลือกของผู้เล่น โดย:
- ตรวจสอบว่ามีผู้เล่นครบสองคนแล้ว
- ตรวจสอบว่าผู้เล่นยังไม่ได้ทำการ commit
- ตรวจสอบว่าผู้เรียกฟังก์ชันเป็นหนึ่งในผู้เล่น
- เก็บค่า hash ในตัวแปร player_commit
- เรียกฟังก์ชัน commit ของ contract CommitReveal
- เพิ่มจำนวนการ commit และตั้งเวลาเริ่มใหม่ถ้าทั้งสองคน commit แล้ว

โดยผู้เล่นต้องสร้าง hash ของตัวเลือกของตัวเองก่อนส่งมา ซึ่งทำให้อีกฝ่ายไม่รู้ว่าเลือกอะไร

## ส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที

1. **การกำหนด Time out**:

uint public constant TIMEOUT_SECONDS = 300;

สัำหนดเวลาหมดอายุไว้ที่ 300 วินาที ซึ่งใช้ในการกำหนดว่าเมื่อไหร่ที่ผู้เล่นสามารถขอคืนเงินหรือบังคับจบเกมได้

2. **การบันทึกเวลาเริ่มต้น**:

if (numPlayer == 0) {
    timeUnit.setStartTime();
}

และ

if (numPlayer == 2) {
    timeUnit.setStartTime(); 
}

และ

if (numInput == 2) {
    timeUnit.setStartTime(); 
}

ตั้งเวลาเริ่มต้นใหม่ในหลายจุด ได้แก่:
- เมื่อผู้เล่นคนแรกเข้าร่วม
- เมื่อผู้เล่นครบสองคน
- เมื่อทั้งสองคน commit แล้ว

เป็นการรีเซ็ตนาฬิกาที่ใช้สำหรับ timeout ทุกครั้งที่มีการเปลี่ยนสถานะสำคัญของเกม

## ส่วนที่ทำการ reveal และนำ choice มาตัดสินผู้ชนะ

1. **ฟังก์ชัน revealChoice()**:

function revealChoice(bytes32 rawData) public {
    require(numPlayer == 2, "Not enough players");
    require(player_commit[msg.sender] != bytes32(0), "You did not commit");
    
    commitreveal.reveal(rawData);
    
    uint8 choice = uint8(rawData[31]); 
    require(choice <= 4, "Invalid choice");
    
    player_revealed[msg.sender] = choice;
    hasRevealed[msg.sender] = true;
    
    if (hasRevealed[players[0]] && hasRevealed[players[1]]) {
        _checkWinnerAndPay();
        _resetGame();
    }
}

ฟังก์ชันนี้:
- ตรวจสอบว่ามีผู้เล่นครบและผู้เล่นได้ทำการ commit แล้ว
- เรียกฟังก์ชัน reveal ของ contract CommitReveal (ตรวจสอบว่า hash ของ rawData ตรงกับ commit ที่ส่งไปก่อนหน้านี้)
- แยกตัวเลือก (0-4) จากตำแหน่งสุดท้ายของ bytes32
- ตรวจสอบว่าตัวเลือกถูกต้อง (≤ 4)
- บันทึกตัวเลือกและสถานะการ reveal
- ถ้าทั้งสองคน reveal แล้ว ตรวจสอบผู้ชนะและจ่ายเงิน

2. **ฟังก์ชัน _checkWinnerAndPay()**:

function _checkWinnerAndPay() private {
    uint p0Choice = player_revealed[players[0]] - 1;
    uint p1Choice = player_revealed[players[1]] - 1;
    address payable account0 = payable(players[0]);
    address payable account1 = payable(players[1]);

    if (_isWinner(p0Choice, p1Choice)) {
        account0.transfer(reward);
    } else if (_isWinner(p1Choice, p0Choice)) {
        account1.transfer(reward);
    } else {
        _refundBothplayer();
    }
}

ฟังก์ชันนี้:
- ดึงตัวเลือกของผู้เล่นทั้งสอง (ลบ 1 เพื่อให้เริ่มจาก 0-4)
- ตรวจสอบว่าใครชนะโดยใช้ฟังก์ชัน _isWinner
- ถ้าผู้เล่น 0 ชนะ: ส่งเงินทั้งหมดให้ผู้เล่น 0
- ถ้าผู้เล่น 1 ชนะ: ส่งเงินทั้งหมดให้ผู้เล่น 1
- ถ้าเสมอ: แบ่งเงินให้ทั้งสองคนเท่าๆ กัน

3. **ฟังก์ชัน _isWinner()**:

function _isWinner(uint choice1, uint choice2) private pure returns (bool) {
    return (
        (choice1 == 0 && (choice2 == 2 || choice2 == 3)) || 
        (choice1 == 1 && (choice2 == 0 || choice2 == 4)) || 
        (choice1 == 2 && (choice2 == 1 || choice2 == 3)) || 
        (choice1 == 3 && (choice2 == 1 || choice2 == 4)) || 
        (choice1 == 4 && (choice2 == 0 || choice2 == 2))    
    );
}

ฟังก์ชันนี้กำหนดกฎการชนะของเกม RPSLS โดย:
- 0 (Rock) ชนะ 2 (Scissors) และ 3 (Lizard)
- 1 (Paper) ชนะ 0 (Rock) และ 4 (Spock)
- 2 (Scissors) ชนะ 1 (Paper) และ 3 (Lizard)
- 3 (Lizard) ชนะ 1 (Paper) และ 4 (Spock)
- 4 (Spock) ชนะ 0 (Rock) และ 2 (Scissors)

