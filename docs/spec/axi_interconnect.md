# AXI4 1-to-N Interconnect Specification

## 1. Trạng thái tài liệu

- Trạng thái: thiết kế kiến trúc trước implementation.
- Phiên bản: 0.2.
- Phạm vi: một upstream AXI master, N downstream AXI slaves.
- Mục tiêu: thêm peripheral bằng cách instantiate slave, thêm một address-region entry và nối một phần tử port array; không sửa control FSM.
- Protocol profile: AXI4 subset 32-bit, ID 2-bit, tối đa một read transaction và một write transaction outstanding.
- Tài liệu này chưa phải RTL implementation và chưa thay đổi behavior hiện tại.

## 2. Kết luận kiến trúc

Khối SoC fabric được chia thành hai boundary độc lập:

    I-Cache ─┐
    D-Cache ─┼─ cpu_bus_arbiter ── AXI master ── axi_interconnect_1xn ─┬─ RAM
    WriteBuf ─┘                                                       ├─ UART
                                                                      ├─ Timer
                                                                      └─ Default error

- <code>cpu_bus_arbiter</code> chọn requester nội bộ của CPU và tạo một AXI master stream.
- <code>axi_interconnect_1xn</code> decode address, route request, giữ transaction ownership và mux response.
- Không có multi-master arbitration bên trong <code>axi_interconnect_1xn</code>.
- Read path và write path độc lập; một read và một write có thể tiến hành đồng thời.
- Address map và PMA attributes có chung một source of truth, nhưng cache policy và bus routing là hai consumers khác nhau.

### 2.1 CPU read arbitration

<code>cpu_bus_arbiter</code> dùng fixed priority <code>D-Cache &gt; I-Cache</code>. Arbitration chỉ xảy ra khi read FSM ở IDLE; transaction đã grant chạy đến RLAST và không bị preempt. D-Cache được ưu tiên vì data miss giữ instruction già hơn và stall pipeline; I-Cache refill hoàn tất trước cũng chưa tạo forward progress khi D-Cache vẫn pending. Với blocking caches, CPU không thể sinh liên tục D-Cache requests nếu instruction fetch bị đói, nên không cần round-robin state.

Write-buffer path dùng AW/W/B FSM độc lập và không tranh read grant.

### 2.2 CPU response ownership

<code>cpu_bus_arbiter</code> latch <code>rd_owner</code> khi grant read request và dùng state này để route toàn bộ R burst về I-Cache hoặc D-Cache. RID không được dùng làm mux select; mỗi accepted R beat phải có RID khớp ID expected từ <code>rd_owner</code>, nếu sai thì assertion fail. Write path chỉ có WriteBuffer requester nên BID chỉ được kiểm tra bằng expected AWID. Policy này tránh route data sai khi downstream vi phạm ID contract; multiple-outstanding support sau này mới thay ownership register bằng transaction table.

## 3. Vì sao gọi là AXI4 subset

Interface có năm AXI channels: AR, R, AW, W và B cùng AXI ID. Profile vẫn không phải AXI4 interconnect tổng quát vì chỉ hỗ trợ một outstanding transaction trên mỗi direction và bỏ các sideband không có consumer trong SoC hiện tại.

Profile v1 hỗ trợ:

- Address width: 32 bit.
- Data width: 32 bit.
- Byte strobes: 4 bit.
- Burst length: 8 bit, nghĩa là số beat bằng <code>AxLEN + 1</code>.
- Burst size: 3 bit.
- Burst type: FIXED, INCR hoặc WRAP.
- Response: OKAY, EXOKAY, SLVERR hoặc DECERR.
- ID width: 2 bit; ID được echo trên response tương ứng.
- Không out-of-order completion.
- Không PROT, CACHE, LOCK, QoS, REGION hoặc USER signaling.
- Một outstanding read và một outstanding write.

Các tín hiệu bị bỏ phải có giá trị cố định khi nối với external AXI IP yêu cầu chúng:

| Signal | Giá trị v1 |
|---|---:|
| AxLOCK | Normal access, 0 |
| AxQOS | 0 |
| AxREGION | 0 |
| AxUSER | Không hiện diện |
| AxPROT | 0 tại external adapter nếu IP bắt buộc |
| AxCACHE | Giá trị cố định theo external memory contract nếu IP bắt buộc |

### 3.1 Phân bổ ID

| ID | Requester | Channel |
|---:|---|---|
| 2'b00 | I-Cache | AR/R |
| 2'b01 | D-Cache | AR/R |
| 2'b10 | Write buffer | AW/B |
| 2'b11 | Reserved | - |

ID xác định requester phía CPU, không xác định downstream slave. Interconnect vẫn route bằng address-derived target. V1 chỉ có một outstanding transaction mỗi direction nên ID chưa tạo concurrency; nó làm rõ ownership và giữ interface sẵn sàng cho mở rộng sau này. AXI4 không có WID, vì vậy W luôn đi theo thứ tự AW đã được nhận.

## 4. AXI invariants bắt buộc

1. Transfer chỉ xảy ra tại rising edge khi VALID và READY đồng thời bằng 1.
2. Source không được đợi READY rồi mới assert VALID.
3. Khi VALID bằng 1 nhưng READY bằng 0, VALID và toàn bộ payload phải giữ ổn định.
4. RVALID chỉ được xuất hiện sau AR handshake tương ứng.
5. BVALID chỉ được xuất hiện sau AW handshake và transfer chứa WLAST.
6. Mỗi burst phải hoàn thành đủ số beat; error không được kết thúc burst sớm.
7. Burst không được vượt qua biên 4 KiB.
8. WRAP burst chỉ có 2, 4, 8 hoặc 16 beats và start address phải aligned theo beat size.
9. Sau reset, các VALID outputs phải bằng 0.
10. Read transaction ownership giữ nguyên đến khi upstream consume RLAST.
11. Write transaction ownership giữ nguyên đến khi upstream consume B response.
12. RID phải bằng ARID và BID phải bằng AWID của transaction tương ứng.

Các invariant trên bám theo ARM IHI 0022H [1].

## 5. Address map và PMA

### 5.1 Region descriptor

Mỗi region được mô tả bằng một record compile-time:

| Field | Width | Ý nghĩa |
|---|---:|---|
| <code>base</code> | 32 | Địa chỉ đầu region |
| <code>mask</code> | 32 | Mask decode; hit khi <code>(addr & mask) == base</code> |
| <code>target</code> | SOC_TARGET_WIDTH | Downstream slave index |
| <code>readable</code> | 1 | Cho phép read |
| <code>writable</code> | 1 | Cho phép write |
| <code>executable</code> | 1 | Cho phép instruction fetch |
| <code>cacheable</code> | 1 | CPU cache được phép allocate |
| <code>device</code> | 1 | Side-effecting MMIO semantics |
| <code>allow_burst</code> | 1 | Cho phép transaction nhiều beat |

<code>SOC_TARGET_WIDTH</code>, <code>SOC_NUM_SLAVES</code> và <code>SOC_NUM_REGIONS</code>
thuộc <code>soc_addr_map_pkg</code>; interconnect không có bản parameter độc lập của các giá trị này.

Region size phải là lũy thừa của hai và <code>base</code> phải aligned theo region size. Hai region không được overlap. Một slave có thể sở hữu nhiều region nhưng mỗi address chỉ được hit đúng một region.

<code>soc_addr_map_pkg.sv</code> là compile-time source of truth cho descriptor table; v1 không dùng CSR hoặc runtime-programmable map. Cache-side PMA, AR decoder và AW decoder giữ comparator riêng nhưng cùng import table này.

### 5.2 Address map v1

| Region | Base | Mask | Size | Target | R | W | X | Cacheable | Device | Burst |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|
| Shared Memory | 0x0000_0000 | 0xFFF0_0000 | 1 MiB | TARGET_MEM | 1 | 1 | 1 | 1 | 0 | 1 |
| TinyTransformer CSR | 0x1000_0000 | 0xFFFF_FF00 | 256 B | TARGET_TINY | 1 | 1 | 0 | 0 | 1 | 0 |
| ASCON CSR | 0x2000_0000 | 0xFFFF_FF00 | 256 B | TARGET_ASCON | 1 | 1 | 0 | 0 | 1 | 0 |
| APB subsystem | 0x3000_0000 | 0xFFFF_0000 | 64 KiB | TARGET_APB | 1 | 1 | 0 | 0 | 1 | 0 |
| Default | mọi địa chỉ khác | - | - | Error | 0 | 0 | 0 | 0 | 1 | 0 |

UART, I2C, GPIO hoặc SPI là APB slaves được sub-decode bên trong APB subsystem; chúng không chiếm AXI target riêng. RTL FPGA hiện tại chỉ có BRAM và UART nên chưa hiện thực đầy đủ map này.

### 5.3 Hai consumer của cùng address map

- Cache-side PMA decoder dùng <code>cacheable</code>, <code>device</code> và <code>executable</code>.
- AXI interconnect dùng <code>target</code>, access permission và <code>allow_burst</code>.
- I-Cache request tới region không executable phải bị reject.
- D-Cache access tới device region không được lookup, allocate hoặc forward từ write buffer.
- Device access là blocking và tạo ordering boundary với write buffer.
- Uncacheable device read phải là single-beat INCR, không phải cache-line WRAP burst.
- Interconnect không tự biến cache-line burst thành MMIO single beat; AXI master generator phải phát transaction đúng ngay từ đầu.

## 6. Top-level module

Tên dự kiến: <code>axi_interconnect_1xn</code>.

### 6.1 Parameters

| Parameter | Giá trị mặc định | Ý nghĩa |
|---|---:|---|
| <code>DATA_WIDTH</code> | 32 | Read/write data width |
| <code>ID_WIDTH</code> | 2 | AXI transaction ID width |

Address width, slave count, region count và target type lấy từ <code>soc_addr_map_pkg</code> qua
<code>SOC_ADDR_WIDTH</code>, <code>SOC_NUM_SLAVES</code>, <code>SOC_NUM_REGIONS</code> và
<code>soc_target_t</code>. <code>STRB_WIDTH = DATA_WIDTH / 8</code>. <code>DATA_WIDTH</code> phải
chia hết cho 8. V1 được verify chính thức với 32-bit data; parameterization không đồng nghĩa các
width khác đã được chứng minh.

### 6.2 Global I/O

| Port | Direction | Width | Ý nghĩa |
|---|---|---:|---|
| <code>clk</code> | input | 1 | AXI clock |
| <code>rst_n</code> | input | 1 | Active-low synchronous reset bên trong interconnect |

### 6.3 Upstream slave-facing AXI port

Interconnect là slave đối với CPU AXI master, vì vậy prefix canonical là <code>s_axi_*</code>.

#### Read address channel

| Port | Direction | Width | Ý nghĩa |
|---|---|---:|---|
| <code>s_axi_arvalid</code> | input | 1 | AR payload hợp lệ |
| <code>s_axi_arready</code> | output | 1 | Interconnect nhận được AR payload |
| <code>s_axi_arid</code> | input | ID_WIDTH | Requester ID |
| <code>s_axi_araddr</code> | input | 32 | Địa chỉ byte đầu tiên |
| <code>s_axi_arlen</code> | input | 8 | Số read beats trừ 1 |
| <code>s_axi_arsize</code> | input | 3 | Log2 số byte mỗi beat; 010 nghĩa là 4 byte |
| <code>s_axi_arburst</code> | input | 2 | 00 FIXED, 01 INCR, 10 WRAP |

#### Read data channel

| Port | Direction | Width | Ý nghĩa |
|---|---|---:|---|
| <code>s_axi_rvalid</code> | output | 1 | R payload hợp lệ |
| <code>s_axi_rready</code> | input | 1 | Upstream nhận được R payload |
| <code>s_axi_rid</code> | output | ID_WIDTH | Echo ARID của transaction |
| <code>s_axi_rdata</code> | output | 32 | Read data |
| <code>s_axi_rresp</code> | output | 2 | Read response |
| <code>s_axi_rlast</code> | output | 1 | Beat cuối read burst |

#### Write address channel

| Port | Direction | Width | Ý nghĩa |
|---|---|---:|---|
| <code>s_axi_awvalid</code> | input | 1 | AW payload hợp lệ |
| <code>s_axi_awready</code> | output | 1 | Interconnect nhận được AW payload |
| <code>s_axi_awid</code> | input | ID_WIDTH | Requester ID |
| <code>s_axi_awaddr</code> | input | 32 | Địa chỉ byte đầu tiên |
| <code>s_axi_awlen</code> | input | 8 | Số write beats trừ 1 |
| <code>s_axi_awsize</code> | input | 3 | Log2 số byte mỗi beat |
| <code>s_axi_awburst</code> | input | 2 | FIXED, INCR hoặc WRAP |

#### Write data channel

| Port | Direction | Width | Ý nghĩa |
|---|---|---:|---|
| <code>s_axi_wvalid</code> | input | 1 | W payload hợp lệ |
| <code>s_axi_wready</code> | output | 1 | Interconnect nhận được W payload |
| <code>s_axi_wdata</code> | input | 32 | Write data |
| <code>s_axi_wstrb</code> | input | 4 | Một enable bit cho mỗi byte lane |
| <code>s_axi_wlast</code> | input | 1 | Beat cuối write burst |

#### Write response channel

| Port | Direction | Width | Ý nghĩa |
|---|---|---:|---|
| <code>s_axi_bvalid</code> | output | 1 | B payload hợp lệ |
| <code>s_axi_bready</code> | input | 1 | Upstream nhận được B payload |
| <code>s_axi_bid</code> | output | ID_WIDTH | Echo AWID của transaction |
| <code>s_axi_bresp</code> | output | 2 | Write response |

### 6.4 Downstream master-facing AXI port arrays

Interconnect là master đối với peripheral slaves. Mỗi downstream signal là một unpacked array có
chiều <code>[SOC_NUM_SLAVES-1:0]</code> đặt sau tên signal; mỗi phần tử tương ứng một
<code>soc_target_t</code>.

| Channel | Output từ interconnect | Input vào interconnect |
|---|---|---|
| AR | <code>m_axi_arvalid[i]</code>, <code>m_axi_arid[i]</code>, <code>m_axi_araddr[i]</code>, <code>m_axi_arlen[i]</code>, <code>m_axi_arsize[i]</code>, <code>m_axi_arburst[i]</code> | <code>m_axi_arready[i]</code> |
| R | <code>m_axi_rready[i]</code> | <code>m_axi_rvalid[i]</code>, <code>m_axi_rid[i]</code>, <code>m_axi_rdata[i]</code>, <code>m_axi_rresp[i]</code>, <code>m_axi_rlast[i]</code> |
| AW | <code>m_axi_awvalid[i]</code>, <code>m_axi_awid[i]</code>, <code>m_axi_awaddr[i]</code>, <code>m_axi_awlen[i]</code>, <code>m_axi_awsize[i]</code>, <code>m_axi_awburst[i]</code> | <code>m_axi_awready[i]</code> |
| W | <code>m_axi_wvalid[i]</code>, <code>m_axi_wdata[i]</code>, <code>m_axi_wstrb[i]</code>, <code>m_axi_wlast[i]</code> | <code>m_axi_wready[i]</code> |
| B | <code>m_axi_bready[i]</code> | <code>m_axi_bvalid[i]</code>, <code>m_axi_bid[i]</code>, <code>m_axi_bresp[i]</code> |

Ví dụ payload 32-bit được khai báo là
<code>logic [DATA_WIDTH-1:0] m_axi_rdata [SOC_NUM_SLAVES-1:0]</code>. Canonical Verilator,
Vivado và LibreLane/Slang flows đều phải preserve representation này tại RTL boundary; synthesized
netlist có thể flatten array thành một packed vector tương đương.

Chỉ phần tử được selected mới được assert VALID hoặc READY. Mọi phần tử không selected phải nhận VALID/READY bằng 0; payload có thể bằng 0 để giảm switching activity.

## 7. Internal blocks

### 7.1 <code>soc_addr_decode</code>

Pure combinational decoder, không giữ transaction state.

| Port | Direction | Width | Ý nghĩa |
|---|---|---:|---|
| <code>addr</code> | input | 32 | Address cần decode |
| <code>is_write</code> | input | 1 | Access là write |
| <code>is_fetch</code> | input | 1 | Access là instruction fetch |
| <code>burst_len</code> | input | 8 | AxLEN |
| <code>burst_size</code> | input | 3 | AxSIZE |
| <code>burst_type</code> | input | 2 | AxBURST |
| <code>hit</code> | output | 1 | Đúng một region hợp lệ |
| <code>target</code> | output | SOC_TARGET_WIDTH | Slave index |
| <code>cacheable</code> | output | 1 | Cache allocation permitted |
| <code>device</code> | output | 1 | Device semantics |
| <code>executable</code> | output | 1 | Instruction fetch permitted |
| <code>access_ok</code> | output | 1 | Permission và burst policy hợp lệ |
| <code>decode_error</code> | output | 1 | Unmapped, overlap hoặc access bị từ chối |

Decoder phải tạo internal one-hot <code>region_hit[SOC_NUM_REGIONS]</code>. Assertion yêu cầu <code>$onehot0(region_hit)</code>. Overlap là configuration error, không phải runtime priority rule.

Cache-side caller cung cấp trực tiếp <code>is_fetch</code>. Trong interconnect, read request có <code>is_fetch=1</code> khi <code>ARID==2'b00</code>; mọi read ID khác và mọi write có <code>is_fetch=0</code>.

### 7.2 <code>axi_read_router</code>

Chức năng:

- Nhận và latch một AR command tại upstream AR handshake.
- Trong <code>RD_SEND_AR</code>, decode registered command và gửi nó tới đúng real slave hoặc
  read side của internal error responder.
- Latch <code>rd_target_q</code> và <code>rd_error_q</code> tại destination AR/request handshake.
- Route trực tiếp R beats và RID từ selected slave về upstream.
- Giữ response source đến khi upstream consume RLAST.
- Không nhận AR thứ hai trong khi transaction trước chưa hoàn tất.
- Không chứa RDATA buffer hoặc beat counter; selected real slave hoặc error responder sở hữu RLAST.

Router dùng <code>ID_WIDTH</code> và <code>DATA_WIDTH</code> parameters. Address width, downstream
array length và target type lấy trực tiếp từ <code>soc_addr_map_pkg</code>. Downstream AR/R ports là
unpacked arrays có chiều <code>[SOC_NUM_SLAVES-1:0]</code>.

Internal payload widths:

| Payload | Width | Thành phần |
|---|---:|---|
| AR command | 47 | id2 + addr32 + len8 + size3 + burst2 |
| R beat | 37 | id2 + data32 + resp2 + last1 |

### 7.3 <code>axi_write_router</code>

Chức năng:

- Nhận và latch một AW command.
- Decode và latch <code>wr_target_q</code>.
- Gửi AW tới đúng slave.
- Chỉ enable W path sau AW downstream handshake; không buffer W trong interconnect.
- Route trực tiếp B response và BID về upstream.
- Giữ target đến khi upstream consume B.
- Không nhận AW thứ hai trong khi transaction trước chưa hoàn tất.

Internal payload widths:

| Payload | Width | Thành phần |
|---|---:|---|
| AW command | 47 | id2 + addr32 + len8 + size3 + burst2 |
| W beat | 37 | data32 + strb4 + last1 |
| B response | 4 | id2 + resp2 |

AXI cho phép WVALID xuất hiện trước AWVALID. V1 có thể giữ <code>s_axi_wready=0</code> cho đến khi AW đã được interconnect nhận. Điều này hợp lệ vì master phải assert WVALID độc lập với WREADY và giữ payload đến handshake.

### 7.4 <code>axi_default_error</code>

Internal pseudo-slave, không chiếm external slave index.

Read behavior:

- Nhận AR metadata của request bị reject.
- Sinh đúng <code>ARLEN + 1</code> beats.
- <code>RID=ARID</code>, <code>RDATA=0</code>, <code>RRESP=DECERR</code>.
- Chỉ assert RLAST trên beat cuối.
- Giữ từng beat ổn định khi upstream stall.

Write behavior:

- Nhận AW metadata.
- Consume đủ <code>AWLEN + 1</code> W beats.
- Sau beat cuối, sinh <code>BID=AWID</code> và <code>BRESP=DECERR</code>.
- Không được trả B response trước khi AW và final W transfer hoàn tất.

Việc hoàn thành đủ burst khi có error là bắt buộc theo AXI [1].

## 8. Datapath

### 8.1 Read datapath

    s_axi_AR
        │
        ▼
    AR command register ──► address decoder ──► one-hot AR/request demux
                                                   │
                                   ┌───────────────┴──────────────┐
                                   ▼                              ▼
                         selected real slave              default error
                                   │                              │
                                   └───────────────┬──────────────┘
                                                   ▼
                                      selected-response R mux ──► s_axi_R

- AR payload chỉ được capture một lần tại upstream AR handshake.
- Payload xuống slave lấy từ register, không lấy trực tiếp từ live upstream bus.
- Decoder output ổn định vì input là registered AR command. Router latch target/error selection khi
  destination accept command.
- R mux select bằng <code>{rd_error_q, rd_target_q}</code>, không decode lại từ address.
- R mux route nguyên tử <code>{RID,RDATA,RRESP,RLAST}</code> từ cùng selected slave.

### 8.2 Write datapath

    s_axi_AW ─► AW command register ─► decoder ─► wr_target_q ─► AW demux
    s_axi_W  ─────────────────────────────────────► selected W path
    selected B ───────────────────────────────────► s_axi_B

- AW và W là hai AXI channels độc lập.
- AXI4 W không mang address hoặc ID; vì vậy W routing bắt buộc dùng target đã latch từ AW.
- Không được decode W bằng live AWADDR.
- B mux dùng <code>wr_target_q</code> và target chỉ được release sau upstream B handshake.

### 8.3 Direct data routing

- Address commands được register trước khi phát xuống slave.
- R, W và B payload route trực tiếp theo target đã latch; interconnect không chứa response/data FIFO.
- CPU <code>bus_arbiter</code> giữ <code>RREADY=1</code> trong toàn bộ state
  <code>bus_arbiter.RD_DATA</code> và <code>BREADY=1</code> trong <code>WR_RESP</code> theo contract hiện tại.
- Mỗi source vẫn phải giữ VALID và payload ổn định cho đến handshake.

V1 ưu tiên control đơn giản và không thêm latency data path. Register slice chỉ được thêm sau này nếu post-synthesis timing hoặc một master có backpressure thực sự chứng minh cần thiết.

## 9. Control path

### 9.1 State registers

| Register | Width | Ý nghĩa |
|---|---:|---|
| <code>rd_state_q</code> | 2 | Read FSM state |
| <code>rd_target_q</code> | soc_target_t | Read real-slave owner |
| <code>rd_error_q</code> | 1 | Read dùng error responder |
| <code>wr_state_q</code> | 3 | Write FSM state |
| <code>wr_target_q</code> | soc_target_t | Write real-slave owner |
| <code>wr_error_q</code> | 1 | Write dùng error responder |
| <code>wr_id_q</code> | ID_WIDTH | Expected BID và error-response ID |
| <code>wr_len_q</code> | 8 | Write burst length |
| <code>wr_beat_count_q</code> | 8 | W beats đã nhận |
| <code>ar_cmd_q</code> | 47 | Stable AR payload |
| <code>aw_cmd_q</code> | 47 | Stable AW payload |

Read và write registers độc lập. Không dùng một shared target register.

### 9.2 Handshake events

| Event | Biểu thức |
|---|---|
| <code>s_ar_fire</code> | <code>s_axi_arvalid && s_axi_arready</code> |
| <code>m_ar_fire[i]</code> | <code>m_axi_arvalid[i] && m_axi_arready[i]</code> |
| <code>s_r_fire</code> | <code>s_axi_rvalid && s_axi_rready</code> |
| <code>m_r_fire[i]</code> | <code>m_axi_rvalid[i] && m_axi_rready[i]</code> |
| <code>s_aw_fire</code> | <code>s_axi_awvalid && s_axi_awready</code> |
| <code>m_aw_fire[i]</code> | <code>m_axi_awvalid[i] && m_axi_awready[i]</code> |
| <code>s_w_fire</code> | <code>s_axi_wvalid && s_axi_wready</code> |
| <code>m_w_fire[i]</code> | <code>m_axi_wvalid[i] && m_axi_wready[i]</code> |
| <code>s_b_fire</code> | <code>s_axi_bvalid && s_axi_bready</code> |
| <code>m_b_fire[i]</code> | <code>m_axi_bvalid[i] && m_axi_bready[i]</code> |

State transition chỉ dựa vào handshake event, không dựa riêng VALID hoặc READY.

## 10. Read FSM

| State | Output/Action | Exit condition |
|---|---|---|
| <code>RD_IDLE</code> | <code>s_axi_arready=1</code>; mọi destination request VALID=0 | <code>s_ar_fire</code>: latch AR command |
| <code>RD_SEND_AR</code> | Decode registered command; assert ARVALID tới decoded real slave hoặc request VALID tới error responder | Selected destination handshake; latch target/error selection |
| <code>RD_FORWARD_R</code> | Route selected real-slave hoặc error-responder R channel về upstream | <code>s_r_fire && s_axi_rlast</code> |

Transitions:

    RD_IDLE --upstream AR handshake--> RD_SEND_AR
        --destination handshake--> RD_FORWARD_R
        --accepted RLAST---------> RD_IDLE

Read target/error selection được latch tại real-slave AR handshake hoặc error-responder request
handshake và chỉ đổi lại sau khi final response đã được upstream consume. Router không tự đếm beat;
response source chịu trách nhiệm phát đúng RLAST theo ARLEN đã nhận.

## 11. Write FSM

| State | Output/Action | Exit condition |
|---|---|---|
| <code>WR_IDLE</code> | <code>s_axi_awready=1</code>; <code>s_axi_wready=0</code> | <code>s_aw_fire</code>: latch AW và decode |
| <code>WR_SEND_AW</code> | Assert selected AWVALID; upstream W chưa được accept | Selected <code>m_aw_fire</code> |
| <code>WR_DATA</code> | Route trực tiếp upstream W tới selected slave | Selected slave nhận expected final W beat |
| <code>WR_RESP</code> | Route selected B trực tiếp về upstream | <code>s_b_fire</code> |
| <code>WR_ERROR_DATA</code> | Consume đủ W beats, không phát downstream | Expected final W beat được consume |
| <code>WR_ERROR_RESP</code> | Assert BVALID với BRESP=DECERR | <code>s_b_fire</code> |

Transitions:

    WR_IDLE --mapped AW--> WR_SEND_AW --> WR_DATA --> WR_RESP --> WR_IDLE
       │
       └--rejected AW--> WR_ERROR_DATA --> WR_ERROR_RESP ------> WR_IDLE

<code>s_axi_wlast</code> phải assert đúng beat <code>AWLEN</code>. RTL giữ beat counter để assertion kiểm tra contract. Với compliant master, WLAST và expected final beat luôn trùng nhau.

## 12. Burst policy

### 12.1 CPU-generated transactions

| Source | Region type | AxLEN | AxSIZE | AxBURST |
|---|---|---:|---:|---:|
| I-Cache refill | Normal memory | 3 | 2 | WRAP |
| D-Cache refill | Normal memory | 3 | 2 | WRAP |
| D-Cache uncacheable load | Device | 0 | 2 hoặc access size thực | INCR |
| Write-buffer store | Normal/device | 0 | 2 | INCR |

Với 32-bit data bus, <code>AxSIZE=2</code> nghĩa là 4 byte mỗi beat. Byte/halfword stores vẫn dùng 32-bit beat cùng WSTRB tương ứng theo contract hiện tại.

### 12.2 Validation

Một request được route chỉ khi:

- Address hit đúng một region.
- Read/write/fetch permission hợp lệ.
- <code>AxSIZE <= log2(DATA_WIDTH/8)</code>.
- Burst không vượt 4 KiB.
- Toàn bộ burst container thuộc cùng region và cùng target.
- WRAP alignment và length hợp lệ.
- Device region nhận single beat nếu <code>allow_burst=0</code>.

Burst gửi tới TinyTransformer CSR, ASCON CSR hoặc APB subsystem phải được chuyển tới default error responder và hoàn tất bằng <code>DECERR</code>. Interconnect không được split burst thành nhiều single-beat device accesses vì việc đó có thể lặp side effect.

Master protocol violation phải được bắt bằng assertions. Defensive hardware có thể chuyển request bị từ chối sang error responder, nhưng không được sửa âm thầm address, length, size hoặc WLAST.

### 12.3 MMIO ordering

Device access tái sử dụng write buffer path nhưng không có normal buffered-store semantics:

1. Khi PMA báo <code>device=1</code>, D-Cache stall pipeline và chờ write buffer empty.
2. MMIO store được push như entry duy nhất; D-Cache chỉ báo completion sau <code>arb_wr_done</code>, tức sau B response.
3. MMIO load chỉ được phát single-beat AR sau khi write buffer empty; completion chờ R response.
4. Trong khi MMIO transaction active, D-Cache không nhận memory request mới.
5. Normal RAM store vẫn hoàn tất khi được enqueue vào write buffer.

Write buffer phải expose <code>wb_empty</code> và completion pulse <code>wb_drain_done</code> cho D-Cache. Vì pipeline bị giữ và buffer đã drain trước khi push MMIO store, completion kế tiếp chắc chắn thuộc MMIO entry; không cần transaction tag nội bộ hoặc direct write bypass.

## 13. Response semantics

| Encoding | Tên | Nguồn |
|---:|---|---|
| 00 | OKAY | Slave báo transaction thành công |
| 01 | EXOKAY | Không được sinh bởi profile v1 |
| 10 | SLVERR | Slave đã được decode nhưng access thất bại |
| 11 | DECERR | Interconnect không decode hoặc từ chối route |

Interconnect phải truyền nguyên <code>RRESP</code>/<code>BRESP</code> của selected slave. Nó chỉ tự sinh DECERR cho unmapped hoặc rejected access. Không đổi SLVERR thành DECERR.

CPU hiện chưa có architectural bus-fault exception path. Integration v1 vẫn phải preserve response bits đến boundary phù hợp; nếu core tiếp tục bỏ qua response thì đó phải được ghi là known limitation, không được coi error như data hợp lệ.

## 14. Reset behavior

- Interconnect modules sample active-low <code>rst_n</code> synchronously tại cạnh lên của
  <code>clk</code>; SoC boundary phải cung cấp reset đã được đồng bộ.
- Tất cả FSM về IDLE.
- Downstream ARVALID, AWVALID, WVALID bằng 0.
- Upstream RVALID và BVALID bằng 0.
- Target và payload registers không cần reset nếu valid/state đã bảo đảm chúng vô nghĩa.
- Không reset datapath chỉ để tạo giá trị 0; reset chỉ áp dụng cho control state cần thiết.

## 15. Thêm peripheral mới

Ví dụ thêm timer:

1. Instantiate <code>axi_timer</code> tại SoC top.
2. Tăng <code>SOC_NUM_SLAVES</code> từ 4 lên 5 và <code>SOC_TARGET_WIDTH</code> từ 2 lên 3 trong
   <code>soc_addr_map_pkg</code>.
3. Nối timer vào phần tử <code>m_axi_*[4]</code>.
4. Thêm <code>soc_target_t</code> encoding và region descriptor: base, mask, target, PMA attributes.
5. Chạy overlap/elaboration checks.
6. Chạy interconnect regression với mapped, unmapped và backpressure cases.

Không sửa read/write FSM, response mux source code hoặc thêm một nhánh <code>if address == timer</code>. Nếu peripheral chỉ hỗ trợ AXI4-Lite, đặt <code>axi_to_axilite_bridge</code> hoặc slave wrapper tại boundary của peripheral.

## 16. Migration từ RTL hiện tại

### 16.1 Giữ lại

- <code>bus_arbiter.sv</code> tiếp tục là CPU requester arbiter trong bước đầu.
- I-Cache, D-Cache và write-buffer external contracts chưa cần đổi đồng thời.
- BRAM và UART slaves được giữ, nhưng UART contract phải được kiểm tra lại.

### 16.2 Thay thế

- Thay <code>rtl/fpga/axi_decoder.sv</code> bằng <code>axi_interconnect_1xn</code>.
- Chuyển address constants khỏi D-Cache và FPGA top vào một shared address-map package.
- Thay hardcode <code>addr[31:28] == 4'h1</code> bằng PMA decode result.
- Mở rộng <code>bus_arbiter</code> để nhận read transaction attributes thay vì luôn phát 4-beat WRAP.
- Bổ sung ARID/RID/AWID/BID xuyên suốt CPU master, interconnect và slaves.
- AxPROT/AxCACHE không đi vào internal v1; external adapter tự tie nếu external IP bắt buộc.
- Mở rộng D-Cache/write-buffer contract với <code>wb_empty</code> và <code>wb_drain_done</code> để MMIO access có blocking ordering.

### 16.3 Lỗi hiện tại được giải quyết

- Uncacheable UART load không còn phát 4-beat WRAP.
- Unmapped address không còn alias về BRAM.
- Wrong-region instruction fetch có thể bị từ chối.
- Read và write destination được giữ đúng xuyên backpressure.
- Thêm slave không cần copy-paste một decoder/mux branch mới.

## 17. Verification specification

### 17.1 Structural assertions

- <code>$onehot0(region_hit)</code>.
- <code>$onehot0(m_axi_arvalid)</code>.
- <code>$onehot0(m_axi_awvalid)</code>.
- <code>$onehot0(m_axi_wvalid)</code>.
- <code>$onehot0(m_axi_rready)</code>.
- <code>$onehot0(m_axi_bready)</code>.
- Không output VALID nào assert trong reset.
- Region base aligned và region pairs không overlap.

### 17.2 Handshake assertions

- Payload stable khi VALID và không READY cho cả năm channels.
- AR/AW target stable suốt transaction.
- RLAST chỉ trên expected final read beat.
- WLAST đúng expected final write beat.
- BVALID chỉ sau downstream AW handshake và accepted WLAST.
- Không nhận AR mới khi read transaction active.
- Không nhận AW mới khi write transaction active.
- Mọi accepted R beat có <code>RID==rd_id_q</code>; accepted B có <code>BID==wr_id_q</code>.
- CPU response mux select bằng latched <code>rd_owner</code>, không bằng live RID.
- CPU <code>bus_arbiter</code> giữ RREADY trong <code>bus_arbiter.RD_DATA</code> và BREADY trong
  <code>WR_RESP</code>.

### 17.3 Directed tests

1. Single-beat RAM read/write.
2. Four-beat INCR burst.
3. Four-beat WRAP burst bắt đầu tại từng word offset trong cache line.
4. Slave chèn khoảng trống RVALID giữa các read beats.
5. AW stall, W stall và B stall độc lập.
6. WVALID xuất hiện trước khi interconnect assert WREADY.
7. Read và write chạy đồng thời tới hai slaves khác nhau.
8. Read và write chạy đồng thời tới cùng slave.
9. UART single-beat read/write.
10. Unmapped read trả đủ <code>ARLEN+1</code> DECERR beats.
11. Unmapped write consume đủ W beats rồi trả DECERR.
12. Region boundary, 4 KiB boundary và invalid WRAP rejection.
13. Reset giữa idle; reset giữa transaction được kiểm tra theo system reset policy.
14. Randomized ARREADY, RVALID, AWREADY, WREADY và BVALID stalls với scoreboard.
15. Regression I-Cache, D-Cache, fetch path và RV32UI cho cả FPGA7/ASAP7.
16. RID/BID echo đúng cho I-Cache, D-Cache, write buffer và default error.
17. MMIO store chờ normal write-buffer entries cũ, rồi chỉ complete sau B response.
18. MMIO load không được vượt qua pending write-buffer store.
19. Khi I-Cache và D-Cache cùng request tại read IDLE, D-Cache được grant; I-Cache được phục vụ sau D-Cache RLAST.
20. Wrong RID/BID gây assertion failure và không được dùng để thay đổi response destination.

### 17.4 Definition of done

- Verilator lint không có combinational-loop hoặc latch warning mới.
- Directed interconnect tests pass ở mọi slave count được support.
- Assertions không fail trong randomized backpressure test.
- Existing FPGA7 và ASAP7 regressions giữ nguyên kết quả.
- UART software demo vẫn hoạt động.
- Uncacheable load dùng <code>ARLEN=0</code>, không còn cache-line burst.
- Vivado synthesis không đặt critical path qua address decoder hoặc response mux.
- Một dummy third slave được thêm chỉ bằng port-array connection và region entry.

## 18. Performance, area và ROI

- Hai 32-bit response muxes và one-hot request demux là datapath chính.
- Decoder cost tăng theo <code>SOC_NUM_REGIONS</code>, không theo toàn bộ 32-bit address space.
- Registered AR/AW command path thêm một cycle; R/W/B data path không thêm latency.
- Read và write độc lập giữ được concurrency hiện có.
- Một outstanding mỗi direction phù hợp blocking L1 caches; ID hiện dùng cho ownership, chưa tăng concurrency.
- Không có FIFO nên area/control nhỏ và refill vẫn đạt một beat mỗi cycle khi slave trả liên tục.
- Khi xuất hiện DMA hoặc accelerator master, giữ nguyên slave-side router và thay upstream bằng multi-master arbitration/crossbar layer.

## 19. Non-goals v1

- Multi-master arbitration.
- Multiple outstanding và out-of-order completion.
- Width conversion.
- Clock-domain crossing.
- AXI-to-APB conversion.
- Cache coherence.
- Atomic/exclusive accesses.
- QoS.
- Timeout recovery bên trong interconnect.
- Runtime-programmable address map.

Các chức năng này phải là adapters hoặc thế hệ interconnect tiếp theo, không được làm phình FSM v1.

## 20. Tài liệu tham khảo

1. [Arm AMBA AXI and ACE Protocol Specification, IHI 0022H](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf)
2. [Arm Introduction to AMBA AXI4](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Learn%20the%20Architecture/102202_0100_01_Introduction_to_AMBA_AXI.pdf)
3. [Current CPU bus arbiter](../../rtl/cpu/cache/bus_arbiter.sv)
4. [Current FPGA AXI decoder](../../rtl/fpga/axi_decoder.sv)
5. [Current ASAP7 D-Cache](../../rtl/cpu/cache/dcache_7stg_asap7.sv)
