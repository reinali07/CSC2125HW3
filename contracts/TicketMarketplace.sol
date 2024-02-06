// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ITicketNFT} from "./interfaces/ITicketNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TicketNFT} from "./TicketNFT.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol"; 
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TicketMarketplace is ITicketMarketplace, Ownable {
    TicketNFT public nftContract;
    uint128 public currentEventId;
    IERC20 public ERC20Address;

    address private _erc20Address;

    mapping(uint128 eventId => Event) public events;

    struct Event {
        uint128 nextTicketToSell;
        uint128 maxTickets;
        uint256 pricePerTicket;
        uint256 pricePerTicketERC20;
    }

    constructor(address erc20Address) Ownable(msg.sender) {
        nftContract = new TicketNFT();
        currentEventId = 0;
        ERC20Address = IERC20(erc20Address);
    }

    function _checkOwner() internal view override(Ownable) {
        if (owner() != _msgSender()) {
            revert("Unauthorized access");
            //revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function createEvent(uint128 maxTickets, uint256 pricePerTicket, uint256 pricePerTicketERC20) public onlyOwner {
        uint128 eventId = currentEventId++;
        events[eventId] = Event(0,maxTickets,pricePerTicket,pricePerTicketERC20);
        emit EventCreated(eventId, maxTickets, pricePerTicket, pricePerTicketERC20);
    }

    function setMaxTicketsForEvent(uint128 eventId, uint128 newMaxTickets) public onlyOwner {
        require(newMaxTickets >= events[eventId].maxTickets, "The new number of max tickets is too small!");
        events[eventId].maxTickets = newMaxTickets;
        emit MaxTicketsUpdate(eventId, newMaxTickets);
    }

    function setPriceForTicketETH(uint128 eventId, uint256 price) public onlyOwner {
        events[eventId].pricePerTicket = price;
        emit PriceUpdate(eventId, price, "ETH");
    }

    function setPriceForTicketERC20(uint128 eventId, uint256 price) public onlyOwner {
        events[eventId].pricePerTicketERC20 = price;
        emit PriceUpdate(eventId, price, "ERC20");
    }

    function buyTickets(uint128 eventId, uint128 ticketCount) payable public {
        uint256 id;

        (bool safemul, uint256 totalTransactionPrice) = Math.tryMul(ticketCount,events[eventId].pricePerTicket);
        require(safemul,"Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");

        uint256 postTransactionTicketsSold = uint256(events[eventId].nextTicketToSell) + uint256(ticketCount);
        require(postTransactionTicketsSold <= events[eventId].maxTickets,"We don't have that many tickets left to sell!");

        require(msg.value >= totalTransactionPrice, "Not enough funds supplied to buy the specified number of tickets.");

        for (uint128 i = 0; i < ticketCount; i++) {
            uint128 seat = events[eventId].nextTicketToSell++;
            id = (uint256(eventId) << 128) + uint256(seat);
            nftContract.mintFromMarketPlace(msg.sender,id);
        }
        
        emit TicketsBought(eventId,ticketCount,"ETH");
    }

    function buyTicketsERC20(uint128 eventId, uint128 ticketCount) public {
        uint256 id;

        (bool safemul, uint256 totalTransactionPrice) = Math.tryMul(ticketCount,events[eventId].pricePerTicketERC20);
        require(safemul,"Overflow happened while calculating the total price of tickets. Try buying smaller number of tickets.");

        uint256 postTransactionTicketsSold = uint256(events[eventId].nextTicketToSell) + uint256(ticketCount);
        require(postTransactionTicketsSold <= events[eventId].maxTickets,"We don't have that many tickets left to sell!");

        require(ERC20Address.transferFrom(msg.sender,address(this),totalTransactionPrice), "Not enough funds supplied to buy the specified number of tickets.");

        for (uint128 i = 0; i < ticketCount; i++) {
            uint128 seat = events[eventId].nextTicketToSell++;
            id = (uint256(eventId) << 128) + uint256(seat);
            nftContract.mintFromMarketPlace(msg.sender,id);
        }

        emit TicketsBought(eventId,ticketCount,"ERC20");
    }

    function setERC20Address(address newERC20Address) public onlyOwner {
        ERC20Address = IERC20(newERC20Address);
        emit ERC20AddressUpdate(newERC20Address);
    }
}