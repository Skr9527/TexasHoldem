// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 牌相关的库
library LibCard {
    // 根据牌值返回牌的花色和点数
    function getNameByCardValue(uint256 card) internal pure returns (uint256 suit, uint256 rank, string memory cardName) {
        string[4] memory cardColors = [unicode"♣", unicode"♦", unicode"♥", unicode"♠"];
        string[13] memory cardNames = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "Ace"];
        suit = card / 13;
        rank = card % 13;
        cardName = string.concat(cardColors[uint8(suit)] , " ", cardNames[uint8(rank)]);
    }

    // 卡牌排序函数（按照值排序）
    function bubbleSort(uint256[] memory _arr) internal pure returns (uint256[] memory) {
        for (uint256 i = 0; i < _arr.length; i++) {
            for (uint256 j = 0; j < _arr.length - i - 1; j++) {
                if (_arr[j] > _arr[j + 1]) {
                    uint256 temp = _arr[j];
                    _arr[j] = _arr[j + 1];
                    _arr[j + 1] = temp;
                }
            }
        }
        return _arr;
    }

    // 卡牌排序函数（按照卡牌的点数排序）
    function sortByCardScore(uint256[] memory _cards) internal pure returns (uint256[] memory) {
        uint256[] memory cardScores = new uint256[](_cards.length);
        for(uint256 i = 0; i < _cards.length; i++) {
            cardScores[i] = _cards[i] % 13;
        }
        for (uint256 i = 0; i < cardScores.length; i++) {
            for (uint256 j = 0; j < cardScores.length - i - 1; j++) {
                if (cardScores[j] > cardScores[j + 1]) {
                    uint256 temp = cardScores[j];
                    cardScores[j] = cardScores[j + 1];
                    cardScores[j + 1] = temp;
                }
            }
        }
        return cardScores;
    }
        
    // 判断是否是三条
    function isThreeOfAKind(uint256[] memory cards) pure internal returns (bool) {
        uint256[] memory sorted = sortByCardScore(cards);
        uint256 currIndex = 0;
        uint256 count = 1;
        for(uint256 i = 1; i < sorted.length; i++) {
            if(sorted[i] == sorted[currIndex]) {
                count++;
            } else {
                currIndex = i;
                count = 1;
            }

            if(count == 3) {
                return true;
            } 
        }
       
        return false;
    }

    // 判断是否是两对
    function isTwoPair(uint256[] memory cards) pure internal returns (bool) {
        uint256[] memory sorted = sortByCardScore(cards);
        uint256 currIndex = 0;
        uint256 count = 1;
        uint256 pairs = 0;
        for (uint256 i = 1; i < sorted.length; i++) {
            if (sorted[i] == sorted[currIndex]) {
                count++;
            } else {
                if(count >= 2) {
                    pairs++;
                }
                count = 1;
                currIndex = i;
            }
        }
        if (pairs == 2) {
            return true;
        }
        return false;
    }

    
    // 判断是否是一对
    function isPair(uint256[] memory cards) pure internal returns (bool) {
        uint256[] memory sorted = sortByCardScore(cards);
        for (uint256 i = 0; i < sorted.length - 1; i++) {
            if (sorted[i] == sorted[i + 1]) {
                return true;
            }
        }
        return false;
    }
        
    // 判断是否是顺子
    function isStraight(uint256[] memory cards) pure internal returns (bool) {
        uint256[] memory sorted = sortByCardScore(cards);
        uint256 currIndex = 0;
        uint256 rank = 1;
        uint256 count = 1;
        for (uint256 i = 1; i < sorted.length; i++) {
            if(sorted[i] - sorted[currIndex] < rank) {
                // 重复的卡牌
                continue;
            } else if(sorted[i] - sorted[currIndex] == rank) {
                // 连续卡牌
                count++;
                rank++;
            } else {
                // 非连续卡牌
                currIndex = i;
                count = 1;
                rank = 1;
            }
            // 连续5张递增的牌
            if(count >= 5) {
                return true;
            }
        }

        return false;
    }

    // 判断是否是皇家同花顺
    function isRoyalFlush(uint256[] memory cards) pure internal returns (bool) {
        uint256[] memory sorted = bubbleSort(cards);
        uint256[4] memory suitCounts;
        for (uint256 i = 0; i < sorted.length; i++) {
            suitCounts[sorted[i] / 13]++;
        }
        for (uint256 i = 0; i < 4; i++) {
            if (suitCounts[i] >= 5) {
                uint256 index = 0;
                while (sorted[index] / 13 != i) {
                    index++;
                }
                uint256 straightCount = 1;
                uint256 currentRank = sorted[index] % 13;
                if (currentRank == 8) {
                    for (uint256 j = index + 1; j < sorted.length; j++) {
                        if (sorted[j] / 13 == i && sorted[j] % 13 == currentRank + 1) {
                            straightCount++;
                            if (straightCount == 5) {
                                return true;
                            }
                            currentRank++;
                        } else if (sorted[j] / 13 != i) {
                            break;
                        }
                    }
                }
                break;  // 7张牌，判断一次即可，剩余不足七张
            }
        }
        return false;
    }

    // 判断是否是同花顺
    function isStraightFlush(uint256[] memory cards) pure internal returns (bool) {
        uint256[] memory sorted = bubbleSort(cards);
        uint256[4] memory suitCounts;
        for (uint256 i = 0; i < sorted.length; i++) {
            suitCounts[sorted[i] / 13]++;
        }
        for (uint256 i = 0; i < 4; i++) {
            if (suitCounts[i] >= 5) {
                uint256 index = 0;
                while (sorted[index] / 13 != i) {
                    index++;
                }
                uint256 straightCount = 1;
                uint256 currentRank = sorted[index] % 13;
                for (uint256 j = index + 1; j < sorted.length; j++) {
                    if (sorted[j] / 13 == i && sorted[j] % 13 == currentRank + 1) {
                        straightCount++;
                        if (straightCount == 5) {
                            return true;
                        }
                        currentRank++;
                    } else if (sorted[j] / 13 != i) {
                        break;
                    }
                }
            }
        }
        return false;
    }

    // 判断是否是四条
    function isFourOfAKind(uint256[] memory cards) internal pure returns(bool) {
        uint256 count;
        for(uint256 i = 0; i < cards.length; i++) {
            count = 0;
            for(uint256 j = 0; j < cards.length; j++) {
                if(cards[i] % 13 == cards[j] % 13){
                    count++;
                }
            }
            if(count == 4) {
                return true;
            }
        }
        return false;
    }
    
    // 判断是否是满堂红（葫芦）
    function isFullHouse(uint256[] memory cards) internal pure returns(bool) {
        // 排序
        uint256[] memory sorted = sortByCardScore(cards);
        uint8 threeCount = 0;
        uint8 twoCount = 0;
        for (uint8 i = 0; i < sorted.length; i++) {
            uint8 count = 1;
            for (uint8 j = i + 1; j < sorted.length; j++) {
                if (sorted[j] == sorted[i]) {
                    count++;
                } else {
                    i = j - 1;
                    break;
                }
            }
            if (count == 3) {
                threeCount++;
            } else if (count == 2) {
                twoCount++;
            }
        }
        return (threeCount == 1 && twoCount == 1) || (threeCount == 2);
    }
    
    // 判断是否是同花
    function isFlush(uint256[] memory cards) pure internal returns (bool) {
        uint256[] memory sorted = bubbleSort(cards);
        uint256[4] memory suitCounts;
        for (uint256 i = 0; i < sorted.length; i++) {
            suitCounts[sorted[i] / 13]++;
        }
        for (uint256 i = 0; i < 4; i++) {
            if (suitCounts[i] >= 5) {
                return true;
            }
        }
        return false;
    }

    // 计算玩家的手牌排名
    function calculateHandRank(uint256[] memory cards) pure internal returns (uint256) {
        // 依次检查不同的牌型
        if (isRoyalFlush(cards)) {
            return 10;
        }
        if (isStraightFlush(cards)) {
            return 9;
        }
        if (isFourOfAKind(cards)) {
            return 8;
        }
        if (isFullHouse(cards)) {
            return 7;
        }
        if (isFlush(cards)) {
            return 6;
        }
        if (isStraight(cards)) {
            return 5;
        }
        if (isThreeOfAKind(cards)) {
            return 4;
        }
        if (isTwoPair(cards)) {
            return 3;
        }
        if (isPair(cards)) {
            return 2;
        }
        return 1; // 高牌
    }
}