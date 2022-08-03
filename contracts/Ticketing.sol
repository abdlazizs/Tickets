// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IToken.sol";

contract Ticketing {
    //An Interface imported calling funtions from the Token COntract that mint Tokens.
    Itoken iToken;
    
    //Token address is passed in into the Contract upon deployment.
    constructor(address _account){
        iToken = Itoken(_account);
    }
    //A Smart contract that creates, stores and sell tickets to buyers with transparency for both the buyer and the seller.
    struct eventsData {
        address payable owner;
        string event_Id; // string name of the event
        uint128 ticket_prices; // face value price of tickets (in wei)
        uint256 totalTickets; // total tickets
        uint64  available_tickets; // total number of ticket
        uint256 deadline; //time deadline of events
        uint256 funds; //funds the event generated
        uint256 index;
        bool exists; // if the event exists
        bool per_customer_limit; // per customer limit
        uint64 max_per_customer; //maximum event per customer
        mapping(address => Customer) tickets; //a mapping the stores the key value of customer in the event
        address[] customers; //address array of the customers.
    }

    struct Customer {
        uint256 index;
        address payable addr;
        bool exists;
        uint64 total_num_tickets;
        uint128 total_paid;
        uint64 num_tickets;
        bytes32 ticketId;
    }
    eventsData[] private genEvents;
    mapping(string => eventsData) public events;
    string[] public event_id_list;
    

    //Events for the state changing functions.

    event event_created(
        address indexed creator,
        string eventName
        
    );
    event ticket_bought(
        address indexed buyer,
        string eventName     
    );
    event fund_withdrawn(
        address indexed creator,
        string eventName,
        uint timestamp
    );
    event ticketPriceChange(
        address indexed creator,
        string EventName,
        uint timestamp
    );
    event event_deleted(address indexed creator, string eventName);

    modifier eventExists(string memory event_id) {
        require(events[event_id].exists, "Event with given ID not found.");
        _;
    }

    modifier onlyHost(string memory event_id) {
        require(
            events[event_id].owner == msg.sender,
            "Sender is not the owner of this event"
        );
        _;
    }

    modifier beforeDeadline(string memory event_id) {
        require(
            events[event_id].deadline > block.timestamp,
            "Event deadline has passed"
        );
        _;
    }

    modifier afterDeadline(string memory event_id) {
        require(
            events[event_id].deadline < block.timestamp,
            "Event deadline has not yet passed"
        );
        _;
    }

    // ----------Event Host functions.-------------

    // creates and stores events for event hosts.
    function createEvent(
        string calldata _event_id,
        uint64  num_tickets,
        uint128  _ticket_prices,
        bool _per_customer_limit,
        uint64 _max_per_customer,
        uint256 _deadline
    ) external {
        require(!events[_event_id].exists, "Given event ID is already in use.");
        require(
            num_tickets > 0,
            "Cannot create event with zero ticket types."
        );
        require(_deadline > block.timestamp, "Deadline cannot be in the past");
        events[_event_id].exists = true;
        events[_event_id].event_Id = _event_id;
        events[_event_id].available_tickets = num_tickets;
        events[_event_id].ticket_prices = _ticket_prices;
        events[_event_id].max_per_customer = _max_per_customer;
        events[_event_id].per_customer_limit = _per_customer_limit;
        events[_event_id].owner = payable(msg.sender);
        events[_event_id].deadline = _deadline;
        events[_event_id].index = event_id_list.length;
        event_id_list.push(_event_id);

        emit event_created(msg.sender, _event_id);
    }
    //add tickets
    function add_tickets(
        string memory event_id,
        uint64  additional_tickets
    ) external eventExists(event_id) onlyHost(event_id) {
        // require(
        //     additional_tickets ==
        //         events[event_id].available_tickets,
        //     "List of number of tickets to add must be of same length as existing list of tickets."
        // );

        for (uint64 i = 0; i < events[event_id].available_tickets; i++) {
            // Check for integer overflow
            require(
                events[event_id].available_tickets + additional_tickets >=
                    events[event_id].available_tickets,
                "Cannot exceed 2^64-1 tickets"
            );
            events[event_id].available_tickets += additional_tickets;
        }
    }

    //get total number of ticket buyers
    function get_customers(string calldata event_id)
        external
        view
        returns (address[] memory)
    {
        return (events[event_id].customers);
    }
    function get_events() external view returns(string[] memory) {
        return event_id_list;

    }

    // view funds of bought tickets
    function view_funds(string calldata event_id)
        external
        view
        eventExists(event_id)
        onlyHost(event_id)
        returns (uint256 current_funds)
    {
        return events[event_id].funds;
    }

    // withdraws funds after deadline exceedes
    function withdraw_funds(string memory event_id)
        external
        eventExists(event_id)
        onlyHost(event_id)
        afterDeadline(event_id)
    {
        uint256 withdraw_amount = events[event_id].funds;
        events[event_id].funds = 0;

        (bool success, ) = events[event_id].owner.call{
            value: (withdraw_amount)
        }("");
        require(success, "Withdrawal transfer failed.");
    }

    //---------customer functions-------------
      // available ticketss
    function availableTickets(string memory event_id)
        external
        view
        returns (uint64 )
    {
        return events[event_id].available_tickets;
    }
    //buys ticket
    function buy_tickets(
        string memory event_id,
        
        uint64 requested_num_tickets
    ) external payable {
        require(requested_num_tickets > 0);
        
        require(
            requested_num_tickets <=
                events[event_id].available_tickets,
            "Not enough tickets available."
        );
        require(
            !events[event_id].per_customer_limit ||
                (events[event_id].tickets[msg.sender].total_num_tickets +
                    requested_num_tickets <=
                    events[event_id].max_per_customer),
            "Purchase surpasses max per customer."
        );

        uint128 sum_price = uint128(requested_num_tickets) *
            uint128(events[event_id].ticket_prices);
        require(msg.value >= sum_price, "Not enough ether was sent.");

        if (!events[event_id].tickets[msg.sender].exists) {
            events[event_id].tickets[msg.sender].exists = true;
            events[event_id].tickets[msg.sender].addr = payable(msg.sender);
            events[event_id].tickets[msg.sender].index = events[event_id]
                .customers
                .length;
            events[event_id].customers.push(msg.sender);
            events[event_id].tickets[msg.sender].num_tickets = uint64(
                events[event_id].available_tickets
            );
        }

        events[event_id]
            .tickets[msg.sender]
            .total_num_tickets += requested_num_tickets;
        events[event_id].tickets[msg.sender].num_tickets
               += requested_num_tickets;
        events[event_id].tickets[msg.sender].total_paid += sum_price;
        events[event_id].available_tickets
          -= requested_num_tickets;
        events[event_id].tickets[msg.sender].total_paid += sum_price;
        events[event_id].funds += sum_price;
        bytes32 id = _generateTicketId(
            event_id,
        
            requested_num_tickets,
            msg.sender
        );
        events[event_id].tickets[msg.sender].ticketId = id;
        iToken.safeMint(msg.sender,event_id);

        // Return excessive funds
        if (msg.value > sum_price) {
            (bool success, ) = msg.sender.call{value: (msg.value - sum_price)}(
                ""
            );
            require(success, "Return of excess funds to sender failed.");
        }
        emit ticket_bought(msg.sender, event_id);
    }

    // returns ticket
    function return_tickets(string memory event_id)
        external
        beforeDeadline(event_id)
    {
        require(
            events[event_id].tickets[msg.sender].total_num_tickets > 0,
            "User does not own any tickets to this event."
        );
        uint return_amount = events[event_id].tickets[msg.sender].total_paid;
        for (uint64 i = 0; i < events[event_id].available_tickets; i++) {
            // Check for integer overflow
            require(
                events[event_id].available_tickets +
                    events[event_id].tickets[msg.sender].num_tickets >=
                    events[event_id].available_tickets,
                "Failed because returned tickets would increase ticket pool past storage limit."
            );
            events[event_id].available_tickets += events[event_id]
                .tickets[msg.sender]
                .num_tickets;
        }
        events[event_id].funds -= return_amount;
        (bool success, ) = msg.sender.call{value: (return_amount)}("");
        require(success, "Return transfer to customer failed.");
    }

    // generates ticket id
    function viewTickedId(string calldata event_id)
        external
        view
        returns (bytes32)
    {
        return (events[event_id].tickets[msg.sender].ticketId);
    }

    // internal function
    function _generateTicketId(
        string memory _name,
        uint64 _num1,
        address signer
    ) internal pure returns (bytes32) {
        bytes32 gen = bytes32(
            keccak256(abi.encodePacked(_name, _num1, signer))
        );    return gen;
    }
}
