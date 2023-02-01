// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutList, BoutListNode } from "../Objects.sol";

library LibLinkedList {
    function addToBoutList(BoutList storage list, uint boutId) internal {
        list.len++;

        list.nextId++;
        list.nodes[list.nextId] = BoutListNode({ boutId: boutId, prev: 0, next: 0 });

        // set as first node if necessary
        if (list.head == 0) {
            list.head = list.nextId;
            list.tail = list.nextId;
        }
        // add to end of list
        else {
            list.nodes[list.tail].next = list.nextId;
            list.nodes[list.nextId].prev = list.tail;
            list.tail = list.nextId;
        }
    }

    function removeFromBoutList(BoutList storage list, BoutListNode storage node) internal {
        list.len--;

        // was first item?
        if (node.prev == 0) {
            list.head = node.next;
            // set new head's prev to 0
            if (list.head != 0) {
                list.nodes[list.head].prev = 0;
            } else {
                // if no head, no tail
                list.tail = 0;
            }
        } else {
            // set prev item's next to next item
            list.nodes[node.prev].next = node.next;
            // set next item's prev to prev item
            if (node.next != 0) {
                list.nodes[node.next].prev = node.prev;
            } else {
                // set a new tail if necessary
                list.tail = node.prev;
            }
        }
    }
}
