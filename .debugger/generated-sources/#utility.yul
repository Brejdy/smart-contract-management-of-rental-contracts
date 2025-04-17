{

    function allocate_unbounded() -> memPtr {
        memPtr := mload(64)
    }

    function revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b() {
        revert(0, 0)
    }

    function revert_error_c1322bf8034eace5e0b5c7295db60986aa89aae5e0ea0873e4689e076861a5db() {
        revert(0, 0)
    }

    function revert_error_1b9f4a0a5773e33b91aa01db23bf8c55fce1411167c872835e7fa00a4f17d46d() {
        revert(0, 0)
    }

    function revert_error_987264b3b1d58a9c7f8255e93e81c77d86d6299019c33110a076957a3e06e2ae() {
        revert(0, 0)
    }

    function round_up_to_mul_of_32(value) -> result {
        result := and(add(value, 31), not(31))
    }

    function panic_error_0x41() {
        mstore(0, 35408467139433450592217433187231851964531694900788300625387963629091585785856)
        mstore(4, 0x41)
        revert(0, 0x24)
    }

    function finalize_allocation(memPtr, size) {
        let newFreePtr := add(memPtr, round_up_to_mul_of_32(size))
        // protect against overflow
        if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr)) { panic_error_0x41() }
        mstore(64, newFreePtr)
    }

    function allocate_memory(size) -> memPtr {
        memPtr := allocate_unbounded()
        finalize_allocation(memPtr, size)
    }

    function array_allocation_size_t_string_memory_ptr(length) -> size {
        // Make sure we can allocate memory without overflow
        if gt(length, 0xffffffffffffffff) { panic_error_0x41() }

        size := round_up_to_mul_of_32(length)

        // add length slot
        size := add(size, 0x20)

    }

    function copy_calldata_to_memory_with_cleanup(src, dst, length) {

        calldatacopy(dst, src, length)
        mstore(add(dst, length), 0)

    }

    function abi_decode_available_length_t_string_memory_ptr(src, length, end) -> array {
        array := allocate_memory(array_allocation_size_t_string_memory_ptr(length))
        mstore(array, length)
        let dst := add(array, 0x20)
        if gt(add(src, length), end) { revert_error_987264b3b1d58a9c7f8255e93e81c77d86d6299019c33110a076957a3e06e2ae() }
        copy_calldata_to_memory_with_cleanup(src, dst, length)
    }

    // string
    function abi_decode_t_string_memory_ptr(offset, end) -> array {
        if iszero(slt(add(offset, 0x1f), end)) { revert_error_1b9f4a0a5773e33b91aa01db23bf8c55fce1411167c872835e7fa00a4f17d46d() }
        let length := calldataload(offset)
        array := abi_decode_available_length_t_string_memory_ptr(add(offset, 0x20), length, end)
    }

    function abi_decode_tuple_t_string_memory_ptr(headStart, dataEnd) -> value0 {
        if slt(sub(dataEnd, headStart), 32) { revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b() }

        {

            let offset := calldataload(add(headStart, 0))
            if gt(offset, 0xffffffffffffffff) { revert_error_c1322bf8034eace5e0b5c7295db60986aa89aae5e0ea0873e4689e076861a5db() }

            value0 := abi_decode_t_string_memory_ptr(add(headStart, offset), dataEnd)
        }

    }

    function array_length_t_string_memory_ptr(value) -> length {

        length := mload(value)

    }

    function array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, length) -> updated_pos {
        mstore(pos, length)
        updated_pos := add(pos, 0x20)
    }

    function copy_memory_to_memory_with_cleanup(src, dst, length) {

        mcopy(dst, src, length)
        mstore(add(dst, length), 0)

    }

    function abi_encode_t_string_memory_ptr_to_t_string_memory_ptr_fromStack(value, pos) -> end {
        let length := array_length_t_string_memory_ptr(value)
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, length)
        copy_memory_to_memory_with_cleanup(add(value, 0x20), pos, length)
        end := add(pos, round_up_to_mul_of_32(length))
    }

    function abi_encode_tuple_t_string_memory_ptr__to_t_string_memory_ptr__fromStack_reversed(headStart , value0) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_string_memory_ptr_to_t_string_memory_ptr_fromStack(value0,  tail)

    }

    function cleanup_t_bool(value) -> cleaned {
        cleaned := iszero(iszero(value))
    }

    function abi_encode_t_bool_to_t_bool_fromStack(value, pos) {
        mstore(pos, cleanup_t_bool(value))
    }

    function abi_encode_tuple_t_bool__to_t_bool__fromStack_reversed(headStart , value0) -> tail {
        tail := add(headStart, 32)

        abi_encode_t_bool_to_t_bool_fromStack(value0,  add(headStart, 0))

    }

    function cleanup_t_uint160(value) -> cleaned {
        cleaned := and(value, 0xffffffffffffffffffffffffffffffffffffffff)
    }

    function cleanup_t_address(value) -> cleaned {
        cleaned := cleanup_t_uint160(value)
    }

    function validator_revert_t_address(value) {
        if iszero(eq(value, cleanup_t_address(value))) { revert(0, 0) }
    }

    function abi_decode_t_address(offset, end) -> value {
        value := calldataload(offset)
        validator_revert_t_address(value)
    }

    function abi_decode_tuple_t_address(headStart, dataEnd) -> value0 {
        if slt(sub(dataEnd, headStart), 32) { revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b() }

        {

            let offset := 0

            value0 := abi_decode_t_address(add(headStart, offset), dataEnd)
        }

    }

    function panic_error_0x21() {
        mstore(0, 35408467139433450592217433187231851964531694900788300625387963629091585785856)
        mstore(4, 0x21)
        revert(0, 0x24)
    }

    function validator_assert_t_enum$_RentalStatus_$530(value) {
        if iszero(lt(value, 3)) { panic_error_0x21() }
    }

    function cleanup_t_enum$_RentalStatus_$530(value) -> cleaned {
        cleaned := value validator_assert_t_enum$_RentalStatus_$530(value)
    }

    function convert_t_enum$_RentalStatus_$530_to_t_uint8(value) -> converted {
        converted := cleanup_t_enum$_RentalStatus_$530(value)
    }

    function abi_encode_t_enum$_RentalStatus_$530_to_t_uint8_fromStack(value, pos) {
        mstore(pos, convert_t_enum$_RentalStatus_$530_to_t_uint8(value))
    }

    function abi_encode_tuple_t_enum$_RentalStatus_$530__to_t_uint8__fromStack_reversed(headStart , value0) -> tail {
        tail := add(headStart, 32)

        abi_encode_t_enum$_RentalStatus_$530_to_t_uint8_fromStack(value0,  add(headStart, 0))

    }

    function cleanup_t_uint256(value) -> cleaned {
        cleaned := value
    }

    function abi_encode_t_uint256_to_t_uint256_fromStack(value, pos) {
        mstore(pos, cleanup_t_uint256(value))
    }

    function abi_encode_tuple_t_uint256__to_t_uint256__fromStack_reversed(headStart , value0) -> tail {
        tail := add(headStart, 32)

        abi_encode_t_uint256_to_t_uint256_fromStack(value0,  add(headStart, 0))

    }

    function validator_revert_t_uint256(value) {
        if iszero(eq(value, cleanup_t_uint256(value))) { revert(0, 0) }
    }

    function abi_decode_t_uint256(offset, end) -> value {
        value := calldataload(offset)
        validator_revert_t_uint256(value)
    }

    function abi_decode_tuple_t_uint256t_string_memory_ptr(headStart, dataEnd) -> value0, value1 {
        if slt(sub(dataEnd, headStart), 64) { revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b() }

        {

            let offset := 0

            value0 := abi_decode_t_uint256(add(headStart, offset), dataEnd)
        }

        {

            let offset := calldataload(add(headStart, 32))
            if gt(offset, 0xffffffffffffffff) { revert_error_c1322bf8034eace5e0b5c7295db60986aa89aae5e0ea0873e4689e076861a5db() }

            value1 := abi_decode_t_string_memory_ptr(add(headStart, offset), dataEnd)
        }

    }

    function abi_decode_tuple_t_uint256(headStart, dataEnd) -> value0 {
        if slt(sub(dataEnd, headStart), 32) { revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b() }

        {

            let offset := 0

            value0 := abi_decode_t_uint256(add(headStart, offset), dataEnd)
        }

    }

    function abi_encode_tuple_t_uint256_t_uint256_t_bool__to_t_uint256_t_uint256_t_bool__fromStack_reversed(headStart , value2, value1, value0) -> tail {
        tail := add(headStart, 96)

        abi_encode_t_uint256_to_t_uint256_fromStack(value0,  add(headStart, 0))

        abi_encode_t_uint256_to_t_uint256_fromStack(value1,  add(headStart, 32))

        abi_encode_t_bool_to_t_bool_fromStack(value2,  add(headStart, 64))

    }

    function abi_encode_t_address_to_t_address_fromStack(value, pos) {
        mstore(pos, cleanup_t_address(value))
    }

    function abi_encode_tuple_t_address__to_t_address__fromStack_reversed(headStart , value0) -> tail {
        tail := add(headStart, 32)

        abi_encode_t_address_to_t_address_fromStack(value0,  add(headStart, 0))

    }

    function array_length_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr(value) -> length {

        length := mload(value)

    }

    function array_storeLengthForEncoding_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr_fromStack(pos, length) -> updated_pos {
        mstore(pos, length)
        updated_pos := add(pos, 0x20)
    }

    function array_dataslot_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr(ptr) -> data {
        data := ptr

        data := add(ptr, 0x20)

    }

    function abi_encode_t_uint256_to_t_uint256(value, pos) {
        mstore(pos, cleanup_t_uint256(value))
    }

    function abi_encode_t_bool_to_t_bool(value, pos) {
        mstore(pos, cleanup_t_bool(value))
    }

    // struct RentalAgreement.PaymentRecord -> struct RentalAgreement.PaymentRecord
    function abi_encode_t_struct$_PaymentRecord_$540_memory_ptr_to_t_struct$_PaymentRecord_$540_memory_ptr(value, pos)  {
        let tail := add(pos, 0x60)

        {
            // timestamp

            let memberValue0 := mload(add(value, 0x00))
            abi_encode_t_uint256_to_t_uint256(memberValue0, add(pos, 0x00))
        }

        {
            // amount

            let memberValue0 := mload(add(value, 0x20))
            abi_encode_t_uint256_to_t_uint256(memberValue0, add(pos, 0x20))
        }

        {
            // stablecoin

            let memberValue0 := mload(add(value, 0x40))
            abi_encode_t_bool_to_t_bool(memberValue0, add(pos, 0x40))
        }

    }

    function abi_encodeUpdatedPos_t_struct$_PaymentRecord_$540_memory_ptr_to_t_struct$_PaymentRecord_$540_memory_ptr(value0, pos) -> updatedPos {
        abi_encode_t_struct$_PaymentRecord_$540_memory_ptr_to_t_struct$_PaymentRecord_$540_memory_ptr(value0, pos)
        updatedPos := add(pos, 0x60)
    }

    function array_nextElement_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr(ptr) -> next {
        next := add(ptr, 0x20)
    }

    // struct RentalAgreement.PaymentRecord[] -> struct RentalAgreement.PaymentRecord[]
    function abi_encode_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr_to_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr_fromStack(value, pos)  -> end  {
        let length := array_length_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr(value)
        pos := array_storeLengthForEncoding_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr_fromStack(pos, length)
        let baseRef := array_dataslot_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr(value)
        let srcPtr := baseRef
        for { let i := 0 } lt(i, length) { i := add(i, 1) }
        {
            let elementValue0 := mload(srcPtr)
            pos := abi_encodeUpdatedPos_t_struct$_PaymentRecord_$540_memory_ptr_to_t_struct$_PaymentRecord_$540_memory_ptr(elementValue0, pos)
            srcPtr := array_nextElement_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr(srcPtr)
        }
        end := pos
    }

    function abi_encode_tuple_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr__to_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr__fromStack_reversed(headStart , value0) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr_to_t_array$_t_struct$_PaymentRecord_$540_memory_ptr_$dyn_memory_ptr_fromStack(value0,  tail)

    }

    function store_literal_in_memory_228c9a0332ddaa9d9a874c553a5baa222a6e5ea4874e5f9b279bd63684366610(memPtr) {

        mstore(add(memPtr, 0), "Only landlord can perform this a")

        mstore(add(memPtr, 32), "ction")

    }

    function abi_encode_t_stringliteral_228c9a0332ddaa9d9a874c553a5baa222a6e5ea4874e5f9b279bd63684366610_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 37)
        store_literal_in_memory_228c9a0332ddaa9d9a874c553a5baa222a6e5ea4874e5f9b279bd63684366610(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_228c9a0332ddaa9d9a874c553a5baa222a6e5ea4874e5f9b279bd63684366610__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_228c9a0332ddaa9d9a874c553a5baa222a6e5ea4874e5f9b279bd63684366610_to_t_string_memory_ptr_fromStack( tail)

    }

    function abi_encode_t_uint256_to_t_uint256_fromStack_library(value, pos) {
        mstore(pos, cleanup_t_uint256(value))
    }

    function abi_encode_tuple_t_uint256__to_t_uint256__fromStack_library_reversed(headStart , value0) -> tail {
        tail := add(headStart, 32)

        abi_encode_t_uint256_to_t_uint256_fromStack_library(value0,  add(headStart, 0))

    }

    function abi_decode_t_uint256_fromMemory(offset, end) -> value {
        value := mload(offset)
        validator_revert_t_uint256(value)
    }

    function abi_decode_tuple_t_uint256_fromMemory(headStart, dataEnd) -> value0 {
        if slt(sub(dataEnd, headStart), 32) { revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b() }

        {

            let offset := 0

            value0 := abi_decode_t_uint256_fromMemory(add(headStart, offset), dataEnd)
        }

    }

    function panic_error_0x11() {
        mstore(0, 35408467139433450592217433187231851964531694900788300625387963629091585785856)
        mstore(4, 0x11)
        revert(0, 0x24)
    }

    function checked_add_t_uint256(x, y) -> sum {
        x := cleanup_t_uint256(x)
        y := cleanup_t_uint256(y)
        sum := add(x, y)

        if gt(x, sum) { panic_error_0x11() }

    }

    function store_literal_in_memory_91100a1daa43b12de9b92c1dfdd828e6c73246765df038f3bdbe19b173a285e5(memPtr) {

        mstore(add(memPtr, 0), "Contract is not active")

    }

    function abi_encode_t_stringliteral_91100a1daa43b12de9b92c1dfdd828e6c73246765df038f3bdbe19b173a285e5_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 22)
        store_literal_in_memory_91100a1daa43b12de9b92c1dfdd828e6c73246765df038f3bdbe19b173a285e5(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_91100a1daa43b12de9b92c1dfdd828e6c73246765df038f3bdbe19b173a285e5__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_91100a1daa43b12de9b92c1dfdd828e6c73246765df038f3bdbe19b173a285e5_to_t_string_memory_ptr_fromStack( tail)

    }

    function checked_sub_t_uint256(x, y) -> diff {
        x := cleanup_t_uint256(x)
        y := cleanup_t_uint256(y)
        diff := sub(x, y)

        if gt(diff, x) { panic_error_0x11() }

    }

    function panic_error_0x12() {
        mstore(0, 35408467139433450592217433187231851964531694900788300625387963629091585785856)
        mstore(4, 0x12)
        revert(0, 0x24)
    }

    function checked_div_t_uint256(x, y) -> r {
        x := cleanup_t_uint256(x)
        y := cleanup_t_uint256(y)
        if iszero(y) { panic_error_0x12() }

        r := div(x, y)
    }

    function panic_error_0x22() {
        mstore(0, 35408467139433450592217433187231851964531694900788300625387963629091585785856)
        mstore(4, 0x22)
        revert(0, 0x24)
    }

    function extract_byte_array_length(data) -> length {
        length := div(data, 2)
        let outOfPlaceEncoding := and(data, 1)
        if iszero(outOfPlaceEncoding) {
            length := and(length, 0x7f)
        }

        if eq(outOfPlaceEncoding, lt(length, 32)) {
            panic_error_0x22()
        }
    }

    function store_literal_in_memory_0153a0fa5c2b8f14973ac44f998d2f08e02d48476ef775cbc7ad773348c51291(memPtr) {

        mstore(add(memPtr, 0), "Contract must be pending teminat")

        mstore(add(memPtr, 32), "ion")

    }

    function abi_encode_t_stringliteral_0153a0fa5c2b8f14973ac44f998d2f08e02d48476ef775cbc7ad773348c51291_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 35)
        store_literal_in_memory_0153a0fa5c2b8f14973ac44f998d2f08e02d48476ef775cbc7ad773348c51291(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_0153a0fa5c2b8f14973ac44f998d2f08e02d48476ef775cbc7ad773348c51291__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_0153a0fa5c2b8f14973ac44f998d2f08e02d48476ef775cbc7ad773348c51291_to_t_string_memory_ptr_fromStack( tail)

    }

    function checked_mul_t_uint256(x, y) -> product {
        x := cleanup_t_uint256(x)
        y := cleanup_t_uint256(y)
        let product_raw := mul(x, y)
        product := cleanup_t_uint256(product_raw)

        // overflow, if x != 0 and y != product/x
        if iszero(
            or(
                iszero(x),
                eq(y, div(product, x))
            )
        ) { panic_error_0x11() }

    }

    function store_literal_in_memory_230a13361c5f2f5302d4680985f176f7fc67e698a03b8e8a88f384e302c2de66(memPtr) {

        mstore(add(memPtr, 0), "No pending warning to confirm")

    }

    function abi_encode_t_stringliteral_230a13361c5f2f5302d4680985f176f7fc67e698a03b8e8a88f384e302c2de66_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 29)
        store_literal_in_memory_230a13361c5f2f5302d4680985f176f7fc67e698a03b8e8a88f384e302c2de66(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_230a13361c5f2f5302d4680985f176f7fc67e698a03b8e8a88f384e302c2de66__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_230a13361c5f2f5302d4680985f176f7fc67e698a03b8e8a88f384e302c2de66_to_t_string_memory_ptr_fromStack( tail)

    }

    function increment_t_uint256(value) -> ret {
        value := cleanup_t_uint256(value)
        if eq(value, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) { panic_error_0x11() }
        ret := add(value, 1)
    }

    function store_literal_in_memory_f4d938c17fd6b4d1428cb9cbe9a841a4142bbcb7547e5d7cc6b866f5077b56e7(memPtr) {

        mstore(add(memPtr, 0), "Only Tenant can perform this act")

        mstore(add(memPtr, 32), "ion")

    }

    function abi_encode_t_stringliteral_f4d938c17fd6b4d1428cb9cbe9a841a4142bbcb7547e5d7cc6b866f5077b56e7_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 35)
        store_literal_in_memory_f4d938c17fd6b4d1428cb9cbe9a841a4142bbcb7547e5d7cc6b866f5077b56e7(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_f4d938c17fd6b4d1428cb9cbe9a841a4142bbcb7547e5d7cc6b866f5077b56e7__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_f4d938c17fd6b4d1428cb9cbe9a841a4142bbcb7547e5d7cc6b866f5077b56e7_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_1dfc56bb8f5472a18fbb6fa24f51b090b4ba07dbdbcbe622d6a5a5d9f117aa30(memPtr) {

        mstore(add(memPtr, 0), "Rental contract is not active")

    }

    function abi_encode_t_stringliteral_1dfc56bb8f5472a18fbb6fa24f51b090b4ba07dbdbcbe622d6a5a5d9f117aa30_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 29)
        store_literal_in_memory_1dfc56bb8f5472a18fbb6fa24f51b090b4ba07dbdbcbe622d6a5a5d9f117aa30(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_1dfc56bb8f5472a18fbb6fa24f51b090b4ba07dbdbcbe622d6a5a5d9f117aa30__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_1dfc56bb8f5472a18fbb6fa24f51b090b4ba07dbdbcbe622d6a5a5d9f117aa30_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_90c98312ffc11c0b1e49446d4b4bc69b51cf2a3a904b38f65514d07496756b1b(memPtr) {

        mstore(add(memPtr, 0), "No ETH required for stablecoin d")

        mstore(add(memPtr, 32), "eposit")

    }

    function abi_encode_t_stringliteral_90c98312ffc11c0b1e49446d4b4bc69b51cf2a3a904b38f65514d07496756b1b_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 38)
        store_literal_in_memory_90c98312ffc11c0b1e49446d4b4bc69b51cf2a3a904b38f65514d07496756b1b(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_90c98312ffc11c0b1e49446d4b4bc69b51cf2a3a904b38f65514d07496756b1b__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_90c98312ffc11c0b1e49446d4b4bc69b51cf2a3a904b38f65514d07496756b1b_to_t_string_memory_ptr_fromStack( tail)

    }

    function abi_encode_tuple_t_address_t_address_t_uint256__to_t_address_t_address_t_uint256__fromStack_reversed(headStart , value2, value1, value0) -> tail {
        tail := add(headStart, 96)

        abi_encode_t_address_to_t_address_fromStack(value0,  add(headStart, 0))

        abi_encode_t_address_to_t_address_fromStack(value1,  add(headStart, 32))

        abi_encode_t_uint256_to_t_uint256_fromStack(value2,  add(headStart, 64))

    }

    function validator_revert_t_bool(value) {
        if iszero(eq(value, cleanup_t_bool(value))) { revert(0, 0) }
    }

    function abi_decode_t_bool_fromMemory(offset, end) -> value {
        value := mload(offset)
        validator_revert_t_bool(value)
    }

    function abi_decode_tuple_t_bool_fromMemory(headStart, dataEnd) -> value0 {
        if slt(sub(dataEnd, headStart), 32) { revert_error_dbdddcbe895c83990c08b3492a0e83918d802a52331272ac6fdb6a7c4aea3b1b() }

        {

            let offset := 0

            value0 := abi_decode_t_bool_fromMemory(add(headStart, offset), dataEnd)
        }

    }

    function store_literal_in_memory_1a23c579e6691900c375990c1a015cae25fc70c7839b22193d4e11dfdb530e82(memPtr) {

        mstore(add(memPtr, 0), "Stablecoin deposit failed")

    }

    function abi_encode_t_stringliteral_1a23c579e6691900c375990c1a015cae25fc70c7839b22193d4e11dfdb530e82_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 25)
        store_literal_in_memory_1a23c579e6691900c375990c1a015cae25fc70c7839b22193d4e11dfdb530e82(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_1a23c579e6691900c375990c1a015cae25fc70c7839b22193d4e11dfdb530e82__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_1a23c579e6691900c375990c1a015cae25fc70c7839b22193d4e11dfdb530e82_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_1d7ce188a2590a146d845d06150c8740ee59e799f73449dae7e05a9ca2d79404(memPtr) {

        mstore(add(memPtr, 0), "Insufficient ETH sent")

    }

    function abi_encode_t_stringliteral_1d7ce188a2590a146d845d06150c8740ee59e799f73449dae7e05a9ca2d79404_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 21)
        store_literal_in_memory_1d7ce188a2590a146d845d06150c8740ee59e799f73449dae7e05a9ca2d79404(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_1d7ce188a2590a146d845d06150c8740ee59e799f73449dae7e05a9ca2d79404__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_1d7ce188a2590a146d845d06150c8740ee59e799f73449dae7e05a9ca2d79404_to_t_string_memory_ptr_fromStack( tail)

    }

    function abi_encode_tuple_t_uint256_t_bool__to_t_uint256_t_bool__fromStack_reversed(headStart , value1, value0) -> tail {
        tail := add(headStart, 64)

        abi_encode_t_uint256_to_t_uint256_fromStack(value0,  add(headStart, 0))

        abi_encode_t_bool_to_t_bool_fromStack(value1,  add(headStart, 32))

    }

    function store_literal_in_memory_cd4488c7e0e57eb1463f4d5dea2dbdb84eadd3dfee3ab6286d8dda64f165c2bf(memPtr) {

        mstore(add(memPtr, 0), "Contract has not expired yet")

    }

    function abi_encode_t_stringliteral_cd4488c7e0e57eb1463f4d5dea2dbdb84eadd3dfee3ab6286d8dda64f165c2bf_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 28)
        store_literal_in_memory_cd4488c7e0e57eb1463f4d5dea2dbdb84eadd3dfee3ab6286d8dda64f165c2bf(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_cd4488c7e0e57eb1463f4d5dea2dbdb84eadd3dfee3ab6286d8dda64f165c2bf__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_cd4488c7e0e57eb1463f4d5dea2dbdb84eadd3dfee3ab6286d8dda64f165c2bf_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_7c64de5f0a192a614b2b6c347128a4c9d84fb793ec0f8111a5aa95f9ee9a17a5(memPtr) {

        mstore(add(memPtr, 0), "Contract has been renewed")

    }

    function abi_encode_t_stringliteral_7c64de5f0a192a614b2b6c347128a4c9d84fb793ec0f8111a5aa95f9ee9a17a5_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 25)
        store_literal_in_memory_7c64de5f0a192a614b2b6c347128a4c9d84fb793ec0f8111a5aa95f9ee9a17a5(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_7c64de5f0a192a614b2b6c347128a4c9d84fb793ec0f8111a5aa95f9ee9a17a5__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_7c64de5f0a192a614b2b6c347128a4c9d84fb793ec0f8111a5aa95f9ee9a17a5_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_7afc7a72be43587d677ac4d246a5fea2a500c85f5a4af7db8fa1d4d3abee420a(memPtr) {

        mstore(add(memPtr, 0), "Contract expired without renewal")

    }

    function abi_encode_t_stringliteral_7afc7a72be43587d677ac4d246a5fea2a500c85f5a4af7db8fa1d4d3abee420a_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 32)
        store_literal_in_memory_7afc7a72be43587d677ac4d246a5fea2a500c85f5a4af7db8fa1d4d3abee420a(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_7afc7a72be43587d677ac4d246a5fea2a500c85f5a4af7db8fa1d4d3abee420a__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_7afc7a72be43587d677ac4d246a5fea2a500c85f5a4af7db8fa1d4d3abee420a_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_b5bf9f2e30b4f26b4273babec64689ea7bf4a7b3a7b47dced9a7d95e401d3c80(memPtr) {

        mstore(add(memPtr, 0), "Contract must ber terminated")

    }

    function abi_encode_t_stringliteral_b5bf9f2e30b4f26b4273babec64689ea7bf4a7b3a7b47dced9a7d95e401d3c80_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 28)
        store_literal_in_memory_b5bf9f2e30b4f26b4273babec64689ea7bf4a7b3a7b47dced9a7d95e401d3c80(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_b5bf9f2e30b4f26b4273babec64689ea7bf4a7b3a7b47dced9a7d95e401d3c80__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_b5bf9f2e30b4f26b4273babec64689ea7bf4a7b3a7b47dced9a7d95e401d3c80_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_277e2b5c9c1a213bc288bad6320c4b8da1bed83425c749f358b5ee1006e606e8(memPtr) {

        mstore(add(memPtr, 0), "Deduction exceeds deposit amount")

    }

    function abi_encode_t_stringliteral_277e2b5c9c1a213bc288bad6320c4b8da1bed83425c749f358b5ee1006e606e8_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 32)
        store_literal_in_memory_277e2b5c9c1a213bc288bad6320c4b8da1bed83425c749f358b5ee1006e606e8(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_277e2b5c9c1a213bc288bad6320c4b8da1bed83425c749f358b5ee1006e606e8__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_277e2b5c9c1a213bc288bad6320c4b8da1bed83425c749f358b5ee1006e606e8_to_t_string_memory_ptr_fromStack( tail)

    }

    function abi_encode_tuple_t_uint256_t_string_memory_ptr__to_t_uint256_t_string_memory_ptr__fromStack_reversed(headStart , value1, value0) -> tail {
        tail := add(headStart, 64)

        abi_encode_t_uint256_to_t_uint256_fromStack(value0,  add(headStart, 0))

        mstore(add(headStart, 32), sub(tail, headStart))
        tail := abi_encode_t_string_memory_ptr_to_t_string_memory_ptr_fromStack(value1,  tail)

    }

    function store_literal_in_memory_d2389965d17e696b7ab91b3831ff7377116cacb3e90e1cd3a68ee8be53aac5ef(memPtr) {

        mstore(add(memPtr, 0), "Contract  must be pending termin")

        mstore(add(memPtr, 32), "ation")

    }

    function abi_encode_t_stringliteral_d2389965d17e696b7ab91b3831ff7377116cacb3e90e1cd3a68ee8be53aac5ef_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 37)
        store_literal_in_memory_d2389965d17e696b7ab91b3831ff7377116cacb3e90e1cd3a68ee8be53aac5ef(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_d2389965d17e696b7ab91b3831ff7377116cacb3e90e1cd3a68ee8be53aac5ef__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_d2389965d17e696b7ab91b3831ff7377116cacb3e90e1cd3a68ee8be53aac5ef_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_d668e3fc44508fb6a744f1bb3d880481ff2051fc8d6e34adcac4025dc094c656(memPtr) {

        mstore(add(memPtr, 0), "Landlord has not requested early")

        mstore(add(memPtr, 32), " termination")

    }

    function abi_encode_t_stringliteral_d668e3fc44508fb6a744f1bb3d880481ff2051fc8d6e34adcac4025dc094c656_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 44)
        store_literal_in_memory_d668e3fc44508fb6a744f1bb3d880481ff2051fc8d6e34adcac4025dc094c656(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_d668e3fc44508fb6a744f1bb3d880481ff2051fc8d6e34adcac4025dc094c656__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_d668e3fc44508fb6a744f1bb3d880481ff2051fc8d6e34adcac4025dc094c656_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_8e532d91dd0ca768ff3b3b2a4dd5abfbc074ff244578ba7367e72e0afd350e55(memPtr) {

        mstore(add(memPtr, 0), "Contract terminated early by mut")

        mstore(add(memPtr, 32), "ual agreement")

    }

    function abi_encode_t_stringliteral_8e532d91dd0ca768ff3b3b2a4dd5abfbc074ff244578ba7367e72e0afd350e55_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 45)
        store_literal_in_memory_8e532d91dd0ca768ff3b3b2a4dd5abfbc074ff244578ba7367e72e0afd350e55(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_8e532d91dd0ca768ff3b3b2a4dd5abfbc074ff244578ba7367e72e0afd350e55__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_8e532d91dd0ca768ff3b3b2a4dd5abfbc074ff244578ba7367e72e0afd350e55_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_d013aaf8611dc4fdd8ac78cdaa9a11b47ffb7cd47c821b317fc272e515db86a8(memPtr) {

        mstore(add(memPtr, 0), "Stablecoin payment failed")

    }

    function abi_encode_t_stringliteral_d013aaf8611dc4fdd8ac78cdaa9a11b47ffb7cd47c821b317fc272e515db86a8_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 25)
        store_literal_in_memory_d013aaf8611dc4fdd8ac78cdaa9a11b47ffb7cd47c821b317fc272e515db86a8(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_d013aaf8611dc4fdd8ac78cdaa9a11b47ffb7cd47c821b317fc272e515db86a8__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_d013aaf8611dc4fdd8ac78cdaa9a11b47ffb7cd47c821b317fc272e515db86a8_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_51e6adbf903046ad87a3081c4fdcfc603a6dba6a73d1691f9be889d6f24b66e3(memPtr) {

        mstore(add(memPtr, 0), "Insufficent ETH sent")

    }

    function abi_encode_t_stringliteral_51e6adbf903046ad87a3081c4fdcfc603a6dba6a73d1691f9be889d6f24b66e3_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 20)
        store_literal_in_memory_51e6adbf903046ad87a3081c4fdcfc603a6dba6a73d1691f9be889d6f24b66e3(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_51e6adbf903046ad87a3081c4fdcfc603a6dba6a73d1691f9be889d6f24b66e3__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_51e6adbf903046ad87a3081c4fdcfc603a6dba6a73d1691f9be889d6f24b66e3_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_0a888dcb30bd8f8169fd6c9ea393bce6f1546804f10e1f5cbfe6efbe21d9d170(memPtr) {

        mstore(add(memPtr, 0), "Contract has already expired")

    }

    function abi_encode_t_stringliteral_0a888dcb30bd8f8169fd6c9ea393bce6f1546804f10e1f5cbfe6efbe21d9d170_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 28)
        store_literal_in_memory_0a888dcb30bd8f8169fd6c9ea393bce6f1546804f10e1f5cbfe6efbe21d9d170(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_0a888dcb30bd8f8169fd6c9ea393bce6f1546804f10e1f5cbfe6efbe21d9d170__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_0a888dcb30bd8f8169fd6c9ea393bce6f1546804f10e1f5cbfe6efbe21d9d170_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_a421397f50eb7e04a2f83c6d01588f8a84a62f99fd98efa12beaf86b92866738(memPtr) {

        mstore(add(memPtr, 0), "Contract is not Active")

    }

    function abi_encode_t_stringliteral_a421397f50eb7e04a2f83c6d01588f8a84a62f99fd98efa12beaf86b92866738_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 22)
        store_literal_in_memory_a421397f50eb7e04a2f83c6d01588f8a84a62f99fd98efa12beaf86b92866738(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_a421397f50eb7e04a2f83c6d01588f8a84a62f99fd98efa12beaf86b92866738__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_a421397f50eb7e04a2f83c6d01588f8a84a62f99fd98efa12beaf86b92866738_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_f8cb768d91a07a3fe40c9461d59956a87ff176cdd03e7058fa7581252bc01d92(memPtr) {

        mstore(add(memPtr, 0), "Warning not applicable yet")

    }

    function abi_encode_t_stringliteral_f8cb768d91a07a3fe40c9461d59956a87ff176cdd03e7058fa7581252bc01d92_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 26)
        store_literal_in_memory_f8cb768d91a07a3fe40c9461d59956a87ff176cdd03e7058fa7581252bc01d92(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_f8cb768d91a07a3fe40c9461d59956a87ff176cdd03e7058fa7581252bc01d92__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_f8cb768d91a07a3fe40c9461d59956a87ff176cdd03e7058fa7581252bc01d92_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_6ce10cee5989600cd71cf72af83da82d0937fa4d103294957914fae990bfaaf0(memPtr) {

        mstore(add(memPtr, 0), "Termination not schduled")

    }

    function abi_encode_t_stringliteral_6ce10cee5989600cd71cf72af83da82d0937fa4d103294957914fae990bfaaf0_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 24)
        store_literal_in_memory_6ce10cee5989600cd71cf72af83da82d0937fa4d103294957914fae990bfaaf0(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_6ce10cee5989600cd71cf72af83da82d0937fa4d103294957914fae990bfaaf0__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_6ce10cee5989600cd71cf72af83da82d0937fa4d103294957914fae990bfaaf0_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_10f6d9c0fbc11ce5f457e07e550828826541e924c7e795386af604f5b3179516(memPtr) {

        mstore(add(memPtr, 0), "Termination period not reached")

    }

    function abi_encode_t_stringliteral_10f6d9c0fbc11ce5f457e07e550828826541e924c7e795386af604f5b3179516_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 30)
        store_literal_in_memory_10f6d9c0fbc11ce5f457e07e550828826541e924c7e795386af604f5b3179516(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_10f6d9c0fbc11ce5f457e07e550828826541e924c7e795386af604f5b3179516__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_10f6d9c0fbc11ce5f457e07e550828826541e924c7e795386af604f5b3179516_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_881467b3e23578b9ed12e27a4c69f84927ebeaca58e053105311aea6c177154b(memPtr) {

        mstore(add(memPtr, 0), "More than 3 payments were not re")

        mstore(add(memPtr, 32), "gistered. Contract is terminated")

        mstore(add(memPtr, 64), ".")

    }

    function abi_encode_t_stringliteral_881467b3e23578b9ed12e27a4c69f84927ebeaca58e053105311aea6c177154b_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 65)
        store_literal_in_memory_881467b3e23578b9ed12e27a4c69f84927ebeaca58e053105311aea6c177154b(pos)
        end := add(pos, 96)
    }

    function abi_encode_tuple_t_stringliteral_881467b3e23578b9ed12e27a4c69f84927ebeaca58e053105311aea6c177154b__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_881467b3e23578b9ed12e27a4c69f84927ebeaca58e053105311aea6c177154b_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_03ffb803173f25e55692c464500286f21a0ffcb61670f8de32242278077ee009(memPtr) {

        mstore(add(memPtr, 0), "Auto payment not authorized")

    }

    function abi_encode_t_stringliteral_03ffb803173f25e55692c464500286f21a0ffcb61670f8de32242278077ee009_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 27)
        store_literal_in_memory_03ffb803173f25e55692c464500286f21a0ffcb61670f8de32242278077ee009(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_03ffb803173f25e55692c464500286f21a0ffcb61670f8de32242278077ee009__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_03ffb803173f25e55692c464500286f21a0ffcb61670f8de32242278077ee009_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_2e73255a161f0e55cef93bede2b7477a989a249641c75f51fa2386ef53b9ea35(memPtr) {

        mstore(add(memPtr, 0), "Auto pay failed")

    }

    function abi_encode_t_stringliteral_2e73255a161f0e55cef93bede2b7477a989a249641c75f51fa2386ef53b9ea35_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 15)
        store_literal_in_memory_2e73255a161f0e55cef93bede2b7477a989a249641c75f51fa2386ef53b9ea35(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_2e73255a161f0e55cef93bede2b7477a989a249641c75f51fa2386ef53b9ea35__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_2e73255a161f0e55cef93bede2b7477a989a249641c75f51fa2386ef53b9ea35_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_15cd2fb03edde485a9c697d6a7dd500dfd876a8f75cf313ce03de51cfb4d2586(memPtr) {

        mstore(add(memPtr, 0), "Termination not scheduled")

    }

    function abi_encode_t_stringliteral_15cd2fb03edde485a9c697d6a7dd500dfd876a8f75cf313ce03de51cfb4d2586_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 25)
        store_literal_in_memory_15cd2fb03edde485a9c697d6a7dd500dfd876a8f75cf313ce03de51cfb4d2586(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_15cd2fb03edde485a9c697d6a7dd500dfd876a8f75cf313ce03de51cfb4d2586__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_15cd2fb03edde485a9c697d6a7dd500dfd876a8f75cf313ce03de51cfb4d2586_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_20c7b7cdb5b83713cc9402b4490a621589d860061cf16a2a76372a2852fb353e(memPtr) {

        mstore(add(memPtr, 0), "All debts must be payed")

    }

    function abi_encode_t_stringliteral_20c7b7cdb5b83713cc9402b4490a621589d860061cf16a2a76372a2852fb353e_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 23)
        store_literal_in_memory_20c7b7cdb5b83713cc9402b4490a621589d860061cf16a2a76372a2852fb353e(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_20c7b7cdb5b83713cc9402b4490a621589d860061cf16a2a76372a2852fb353e__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_20c7b7cdb5b83713cc9402b4490a621589d860061cf16a2a76372a2852fb353e_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_f3937fbb4c5ec992e463c933e82bca8607de82e8d56c2f60521b3a4fe0eb2519(memPtr) {

        mstore(add(memPtr, 0), "Tenant terminated the lease agre")

        mstore(add(memPtr, 32), "ement")

    }

    function abi_encode_t_stringliteral_f3937fbb4c5ec992e463c933e82bca8607de82e8d56c2f60521b3a4fe0eb2519_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 37)
        store_literal_in_memory_f3937fbb4c5ec992e463c933e82bca8607de82e8d56c2f60521b3a4fe0eb2519(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_f3937fbb4c5ec992e463c933e82bca8607de82e8d56c2f60521b3a4fe0eb2519__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_f3937fbb4c5ec992e463c933e82bca8607de82e8d56c2f60521b3a4fe0eb2519_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_52da729b66eeb0ad7f60d5d53e0591bd97587a6a90a5eed232dc732a87bf1031(memPtr) {

        mstore(add(memPtr, 0), "Tennant has not asked for renewa")

        mstore(add(memPtr, 32), "l")

    }

    function abi_encode_t_stringliteral_52da729b66eeb0ad7f60d5d53e0591bd97587a6a90a5eed232dc732a87bf1031_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 33)
        store_literal_in_memory_52da729b66eeb0ad7f60d5d53e0591bd97587a6a90a5eed232dc732a87bf1031(pos)
        end := add(pos, 64)
    }

    function abi_encode_tuple_t_stringliteral_52da729b66eeb0ad7f60d5d53e0591bd97587a6a90a5eed232dc732a87bf1031__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_52da729b66eeb0ad7f60d5d53e0591bd97587a6a90a5eed232dc732a87bf1031_to_t_string_memory_ptr_fromStack( tail)

    }

    function store_literal_in_memory_ebf73bba305590e4764d5cb53b69bffd6d4d092d1a67551cb346f8cfcdab8619(memPtr) {

        mstore(add(memPtr, 0), "ReentrancyGuard: reentrant call")

    }

    function abi_encode_t_stringliteral_ebf73bba305590e4764d5cb53b69bffd6d4d092d1a67551cb346f8cfcdab8619_to_t_string_memory_ptr_fromStack(pos) -> end {
        pos := array_storeLengthForEncoding_t_string_memory_ptr_fromStack(pos, 31)
        store_literal_in_memory_ebf73bba305590e4764d5cb53b69bffd6d4d092d1a67551cb346f8cfcdab8619(pos)
        end := add(pos, 32)
    }

    function abi_encode_tuple_t_stringliteral_ebf73bba305590e4764d5cb53b69bffd6d4d092d1a67551cb346f8cfcdab8619__to_t_string_memory_ptr__fromStack_reversed(headStart ) -> tail {
        tail := add(headStart, 32)

        mstore(add(headStart, 0), sub(tail, headStart))
        tail := abi_encode_t_stringliteral_ebf73bba305590e4764d5cb53b69bffd6d4d092d1a67551cb346f8cfcdab8619_to_t_string_memory_ptr_fromStack( tail)

    }

}
