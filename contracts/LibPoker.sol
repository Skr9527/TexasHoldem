// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 扑克牌相关的库
library LibPoker {
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
        for (uint256 i = 0; i < _cards.length; i++) {
            for (uint256 j = 0; j < _cards.length - i - 1; j++) {
                if (_cards[j] % 13 > _cards[j + 1] % 13) {
                    uint256 temp = _cards[j];
                    _cards[j] = _cards[j + 1];
                    _cards[j + 1] = temp;
                }
            }
        }
        return _cards;
    }
         
    // 判断是否是皇家同花顺
    function isRoyalFlush(uint256[] memory cards) pure internal returns (bool, uint256[] memory) {
        // 按照牌值排序
        uint256[] memory sorted = bubbleSort(cards);
        // 记录同一花色的牌的张数
        uint256[4] memory suitCounts;
        for (uint256 i = 0; i < sorted.length; i++) {
            suitCounts[sorted[i] / 13]++;
        }

        // 选中的牌
        uint256[] memory selCards = new uint256[](5);
        // 遍历不同花色
        for (uint256 i = 0; i < 4; i++) {
            // 同花
            if (suitCounts[i] >= 5) {
                uint256 index = 0;
                // 判断牌的花色是否和同花的牌相同
                while (sorted[index] / 13 != i) {
                    index++;
                }

                // 保存同花色第一张牌
                selCards[0] = sorted[index];

                uint256 straightCount = 1;
                // 牌的点数
                uint256 currentRank = sorted[index] % 13;
                // 判断牌是否从10（点数）开始
                if (currentRank == 8) {
                    for (uint256 j = index + 1; j < sorted.length; j++) {
                        // 判断花色和点数
                        if (sorted[j] / 13 == i && sorted[j] % 13 == currentRank + 1) {
                            selCards[straightCount] = sorted[j];
                            straightCount++;
                            if (straightCount == 5) {
                                return (true, selCards);
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
        selCards = new uint256[](0);
        return (false, selCards);
    }

    // 判断是否是同花顺
    function isStraightFlush(uint256[] memory cards) pure internal returns (bool, uint256[] memory) {
        uint256[] memory sorted = bubbleSort(cards);
        // 记录同一花色的牌的张数
        uint256[4] memory suitCounts;
        for (uint256 i = 0; i < sorted.length; i++) {
            suitCounts[sorted[i] / 13]++;
        }

        // 选中的牌
        uint256[] memory selCards = new uint256[](5);
        // 遍历不同花色
        for (uint256 i = 0; i < 4; i++) {
            if (suitCounts[i] >= 5) {
                uint256 index = 0;
                while (sorted[index] / 13 != i) {
                    index++;
                }
                // 保存同花色第一张牌
                selCards[0] = sorted[index];
                uint256 straightCount = 1;
                uint256 currentRank = sorted[index] % 13;
                for (uint256 j = index + 1; j < sorted.length; j++) {
                    if (sorted[j] / 13 == i && sorted[j] % 13 == currentRank + 1) {
                        // 保存同花色，并满足条件的牌
                        selCards[straightCount] = sorted[j];
                        straightCount++;
                        if (straightCount == 5) {
                            return (true, selCards);
                        }
                        currentRank++;
                    } else if (sorted[j] / 13 != i) {
                        break;
                    }
                }
            }
        }
        selCards = new uint256[](0);
        return (false, selCards);
    }

    // 判断是否是四条
    function isFourOfAKind(uint256[] memory cards) internal pure returns(bool, uint256[] memory) {
        uint256 count;
        // 选中的牌
        uint256[] memory selCards = new uint256[](4);
        for(uint256 i = 0; i < cards.length; i++) {
            count = 1;
            // 记录第一张被选中的牌
            selCards[count-1] = cards[i];
            for(uint256 j = i + 1; j < cards.length; j++) {
                if(cards[i] % 13 == cards[j] % 13){
                    count++;
                    selCards[count-1] = cards[j];
                }
            }
            if(count == 4) {
                return (true, selCards);
            }
        }
        selCards = new uint256[](0);
        return (false, selCards);
    }


    // 判断是否是满堂红（葫芦）
    function isFullHouse(uint256[] memory cards) internal pure returns(bool, uint256[] memory) {
        // 统计不同点数出现的牌的次数
        uint8[13] memory countArray;
        // 三条对应的点数
        int256 threePoint = -1;
        // 一对对应的点数
        int256 twoPoint = -1;
        bool isTrue = false;
        // 选中的牌
        uint256[] memory selCards;
        for (uint8 i = 0; i < cards.length; i++) {
            countArray[cards[i] % 13]++;
        }

        // 遍历不同点数的统计记录
        for(uint8 i = 0; i < countArray.length; i++) {
            if(threePoint >= 0) {
                // 已经找到三条，后面出现的三条和一对都按一对算
                if(3 == countArray[i] || 2 == countArray[i]) {
                    twoPoint = int8(i);
                }
            } else {
                // 未找到三条
                if(3 == countArray[i]) {
                    threePoint = int8(i);
                } else if(2 == countArray[i]) {
                    twoPoint = int8(i);
                }
            }

            if(threePoint >= 0 && twoPoint >= 0) break;
        }

        // 是否是葫芦
        isTrue = (threePoint >= 0 && twoPoint >= 0);

        if(isTrue) {
            // 是葫芦，按点数查询并记录牌
            selCards = new uint256[](5);
            uint8 count = 0;
            for (uint8 i = 0; i < cards.length; i++) {
                if(threePoint == int256(cards[i] % 13) || twoPoint == int256(cards[i] % 13)) {
                    selCards[count++] = cards[i];
                    if(count >= 5) break;
                }
            }
        }
        return (isTrue, selCards);
    }
    
    // 判断是否是同花
    function isFlush(uint256[] memory cards) pure internal returns (bool, uint256[] memory) {
        uint256[] memory sorted = bubbleSort(cards);
        uint256[4] memory suitCounts;
        // 选中的牌
        uint256[] memory selCards;
        for (uint256 i = 0; i < sorted.length; i++) {
            suitCounts[sorted[i] / 13]++;
        }
        
        // 遍历花色
        for (uint256 i = 0; i < 4; i++) {
            if (suitCounts[i] >= 5) {
                selCards = new uint256[](5);
                uint8 count = 0;
                for (uint256 j = 0; i < sorted.length; j++) {
                    // 判断花色
                    if(i == sorted[j] / 13) {
                        selCards[count++] = sorted[j];
                        if(count >= 5) break;
                    }
                }
                return (true, selCards);
            }
        }
        return (false, selCards);
    }

    // 判断是否是顺子
    function isStraight(uint256[] memory _cards) pure internal returns (bool, uint256[] memory) {
        // 按照点数排序
        uint256[] memory sorted = sortByCardScore(_cards);
        // 统计不同点数出现的牌的次数
        uint8[13] memory countArray;
        // 选中的牌
        uint256[] memory selCards;
        // 开始位置
        uint8 startIndex = 0;
        for (uint8 i = 0; i < sorted.length; i++) {
            countArray[sorted[i] % 13]++;
        }

        uint8 count = 0;
        for(uint8 i = 0; i < countArray.length; i++) {
            if(countArray[i] > 0) {
                if(0 == count) {
                    startIndex = i;
                }
                count++;
            } else if(count > 0){
                count = 0;
            }

            if(count >= 5) break;
        }

        // 是顺子
        if(count >= 5) {
            selCards = new uint256[](5);
            uint8 rank = 0;
            // 当前点数
            uint256 currScore = 0;
            for (uint8 i = 0; i < sorted.length; i++) {
                // 过滤重复点数的牌
                if(sorted[i] % 13 == (startIndex + rank) && currScore != sorted[i] % 13) {
                    currScore = sorted[i] % 13;
                    selCards[rank++] = sorted[i];
                    if(rank >= 5) break;
                }
            }
            return (true, selCards);
        }

        return (false, selCards);
    }

    // 判断是否是三条
    function isThreeOfAKind(uint256[] memory cards) pure internal returns (bool, uint256[] memory) {
        // 按照点数排序
        uint256[] memory sorted = sortByCardScore(cards);
        uint256 currIndex = 0;
        uint256 count = 1;
        // 选中的牌
        uint256[] memory selCards = new uint256[](3);
        selCards[0] = sorted[0];
        for(uint256 i = 1; i < sorted.length; i++) {
            if(sorted[i] % 13 == sorted[currIndex] % 13) {
                selCards[count++] = sorted[i];
            } else {
                currIndex = i;
                selCards[0] = sorted[i];
                count = 1;
            }

            if(count == 3) {
                return (true, selCards);
            } 
        }
        selCards = new uint256[](0);
        return (false, selCards);
    }

    // 判断是否是两对（不考虑有三条的情况）
    function isTwoPair(uint256[] memory cards) pure internal returns (bool, uint256[] memory) {
        uint256[] memory sorted = sortByCardScore(cards);
        uint256 currIndex = 0;
        uint256 pairs = 0;
        // 选中的牌
        uint256[] memory selCards = new uint256[](4);
        for (uint256 i = 1; i < sorted.length; i++) {
            if (sorted[i] % 13 == sorted[currIndex] % 13) {
                pairs++;
                if(1 == pairs) {
                    selCards[0] = sorted[currIndex];
                    selCards[1] = sorted[i];
                } else if(2 == pairs) {
                    selCards[2] = sorted[currIndex];
                    selCards[3] = sorted[i];
                    return (true, selCards);
                }
                currIndex = i + 1;
                i = currIndex;
            } else {
                currIndex = i;
            }
        }

        selCards = new uint256[](0);
        return (false, selCards);
    }

    // 判断是否是一对
    function isPair(uint256[] memory cards) pure internal returns (bool, uint256[] memory) {
        uint256[] memory sorted = sortByCardScore(cards);
        // 选中的牌
        uint256[] memory selCards;
        for (uint256 i = 0; i < sorted.length - 1; i++) {
            if (sorted[i] % 13 == sorted[i + 1] % 13) {
                selCards = new uint256[](2);
                selCards[0] = sorted[i];
                selCards[1] = sorted[i + 1];
                return (true, selCards);
            }
        }
        return (false, selCards);
    }

    // 计算玩家的手牌排名
    function calculateHandRank(uint256[] memory cards) pure internal returns (uint256, uint256[] memory) {
        // 依次检查不同的牌型
        (bool isTrue, uint256[] memory selCards) = isRoyalFlush(cards);
        if (isTrue) {
            return (10, selCards);
        }

        (isTrue, selCards) = isStraightFlush(cards);
         if (isTrue) {
            return (9, selCards);
        }

        (isTrue, selCards) = isFourOfAKind(cards);
         if (isTrue) {
            return (8, selCards);
        }

        (isTrue, selCards) = isFullHouse(cards);
         if (isTrue) {
            return (7, selCards);
        }

        (isTrue, selCards) = isFlush(cards);
         if (isTrue) {
            return (6, selCards);
        }

        (isTrue, selCards) = isStraight(cards);
        if (isTrue) {
            return (5, selCards);
        }

        (isTrue, selCards) = isThreeOfAKind(cards);
        if (isTrue) {
            return (4, selCards);
        }

        (isTrue, selCards) = isTwoPair(cards);
        if (isTrue) {
            return (3, selCards);
        }

        (isTrue, selCards) = isPair(cards);
        if (isTrue) {
            return (2, selCards);
        }

        return (1, selCards); // 高牌
    }
}