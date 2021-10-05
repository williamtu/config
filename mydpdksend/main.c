/*-
 *   BSD LICENSE
 *
 *   Copyright(c) 2010-2014 Intel Corporation. All rights reserved.
 *   All rights reserved.
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in
 *       the documentation and/or other materials provided with the
 *       distribution.
 *     * Neither the name of Intel Corporation nor the names of its
 *       contributors may be used to endorse or promote products derived
 *       from this software without specific prior written permission.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 *   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 *   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 *   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <sys/types.h>
#include <setjmp.h>
#include <stdarg.h>
#include <ctype.h>
#include <errno.h>
#include <signal.h>
#include <stdbool.h>

#include <rte_os.h>
#include <rte_common.h>
#include <rte_log.h>
#include <rte_memory.h>
#include <rte_memcpy.h>
#include <rte_memzone.h>
#include <rte_eal.h>
#include <rte_per_lcore.h>
#include <rte_launch.h>
#include <rte_atomic.h>
#include <rte_cycles.h>
#include <rte_prefetch.h>
#include <rte_lcore.h>
#include <rte_per_lcore.h>
#include <rte_branch_prediction.h>
#include <rte_interrupts.h>
#include <rte_pci.h>
#include <rte_random.h>
#include <rte_debug.h>
#include <rte_ether.h>
#include <rte_ethdev.h>
#include <rte_ring.h>
#include <rte_mempool.h>
#include <rte_mbuf.h>

#define NB_MBUF   8192

#define MAX_PKT_BURST 32
#define PRINT_STATS_US 1000000
#define TX_QUEUE 2 /* configured tx queue */
static volatile bool force_quit;

/*
 * Configurable number of RX/TX ring descriptors
 */
#define RTE_TEST_RX_DESC_DEFAULT 1024 
#define RTE_TEST_TX_DESC_DEFAULT 1024
static uint16_t nb_rxd = RTE_TEST_RX_DESC_DEFAULT;
static uint16_t nb_txd = RTE_TEST_TX_DESC_DEFAULT;

static const struct rte_eth_conf port_conf = {
	.rxmode = {
		.split_hdr_size = 0,
		.mq_mode = ETH_MQ_RX_NONE,
	},
	.txmode = {
		.mq_mode = ETH_MQ_TX_NONE,
		//.mq_mode = ETH_MQ_TX_VMDQ_ONLY,
	},
};
struct rte_mempool * l2fwd_pktmbuf_pool = NULL;
unsigned long long microflows;

const char packet[] =
"\x00\x02\x03\x04\x05\x06\xa0\x36\x9f\x0c\x94\xe8\x08\x00\x45\x10\x00\x2e\x00\x00\x40\x00\x40\x11\x26\xad\x0a\x00\x00\x01\x0a\x01\x00\x01\x00\x00\x00\x01\x00\x1a\x00\x00\x6e\x65\x74\x6d\x61\x70\x20\x70\x6b\x74\x2d\x67\x65\x6e\x20\x44\x49\x52";

static int
tx(void *arg)
{
	const uint64_t drain_tsc = (rte_get_tsc_hz() + US_PER_S - 1) / US_PER_S * PRINT_STATS_US;
	uint64_t prev_tsc = rte_rdtsc();
	const uint8_t port_id = 0; //XXX
	uint64_t pps = 0;
	unsigned long long seq = 0;
	unsigned lcore_id;
	unsigned queue_id;

        lcore_id = rte_lcore_id();
	queue_id = *(unsigned *)arg;
	printf("TXCORE id %d queue id %d\n", lcore_id, queue_id);

	for (;;) {
		struct rte_mbuf *pkts[MAX_PKT_BURST];
		uint64_t diff_tsc, cur_tsc;
		unsigned nb_tx, i;
		uint8_t *data;

		if (force_quit)
			return 0;

		cur_tsc = rte_rdtsc();
		diff_tsc = cur_tsc - prev_tsc;
		if (unlikely(diff_tsc > drain_tsc)) {
			printf("\tpps TX:%"PRIu64"\n", pps);
			pps = 0;
			prev_tsc = cur_tsc;
		}

		for (i = 0; i < MAX_PKT_BURST; i++) {
			pkts[i] = rte_pktmbuf_alloc(l2fwd_pktmbuf_pool);
			data = rte_pktmbuf_mtod(pkts[i], void *);
			rte_pktmbuf_pkt_len(pkts[i]) = 60;
			rte_pktmbuf_data_len(pkts[i]) = 60;
			rte_memcpy(data, packet, 60);
			seq++;
			seq = seq % microflows;
			data[0x22] = (seq >> 7) & 0xFF; // UDP SRC
			data[0x23] = ((seq & 0x7F) << 1) | 1;

			data[0x24] = (seq >> 22) & 0xFF; // UDP DST
			data[0x25] = ((((seq >> 15) & 0x7F)) << 1) | 1;
		}

		nb_tx = rte_eth_tx_burst(port_id, (uint16_t)queue_id, pkts, (uint16_t) MAX_PKT_BURST);
		pps += nb_tx;
		for (i = nb_tx; i < MAX_PKT_BURST; i++) {
			rte_pktmbuf_free(pkts[i]);
		}
	}

	return 0;
}

static int
rx(__attribute__((unused)) void *dummy)
{
	const uint64_t drain_tsc = (rte_get_tsc_hz() + US_PER_S - 1) / US_PER_S * PRINT_STATS_US;
	uint64_t prev_tsc = rte_rdtsc();
	const uint8_t port_id = 0; //XXX
	uint64_t pps = 0;
	unsigned lcore_id;

        lcore_id = rte_lcore_id();

	printf("RXCORE id %d\n", lcore_id);
	
	for (;;) {
		struct rte_mbuf *pkts[MAX_PKT_BURST];
		unsigned nb_rx, i;
		uint64_t diff_tsc, cur_tsc;

		if (force_quit)
			return 0;

		cur_tsc = rte_rdtsc();
		diff_tsc = cur_tsc - prev_tsc;
		if (unlikely(diff_tsc > drain_tsc)) {
			printf("pps RX:%"PRIu64"\n", pps);
			pps = 0;
			prev_tsc = cur_tsc;
		}
		nb_rx = rte_eth_rx_burst((uint8_t) port_id, 0,
					 pkts, MAX_PKT_BURST);
		//printf("RX %u\n", nb_rx);
		pps += nb_rx;
		for (i = 0; i < nb_rx; i++) {
			rte_pktmbuf_free(pkts[i]);
		}
	}

	return 0;
}

static void
signal_handler(int signum)
{
        if (signum == SIGINT || signum == SIGTERM) {
                printf("\n\nSignal %d received, preparing to exit...\n",
                                signum);
                force_quit = true;
        }
}

int
main(int argc, char **argv)
{
	int ret, i;
	uint8_t nb_ports;
	uint8_t portid;
	unsigned lcore_id;
	unsigned tx_queue_id;
#if 0
    uint16_t vportid;
    char vdev_name[] = "net_af_xdp";
    char vdev_args[] = "iface=enp2s0,queue=0";
#endif
	//unsigned long long new_microflows;

    	printf("Hello\n");
	/* init EAL */
	ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Invalid EAL arguments\n");
	argc -= ret;
	argv += ret;

	if (argc < 2) {
		rte_exit(EXIT_FAILURE, "Please specify number of microflows\n");
	}

        force_quit = false;
        signal(SIGINT, signal_handler);

	microflows = strtoull(argv[1], NULL, 0);

	/* create the mbuf pool */
	l2fwd_pktmbuf_pool = rte_pktmbuf_pool_create("mbuf_pool", NB_MBUF, 32,
		0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
	if (l2fwd_pktmbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot init mbuf pool\n");
#if 0
    if (rte_eal_hotplug_add("vdev", vdev_name, vdev_args) < 0) {
		rte_exit(EXIT_FAILURE, "Cannot hotplug device\n");
    }

    if (rte_eth_dev_get_port_by_name(vdev_name, &vportid) != 0) {
        rte_eal_hotplug_remove("vdev", vdev_name);
		rte_exit(EXIT_FAILURE, "Cannot hotplug device\n");
    }

    printf("vport id %d\n", vportid);
#endif
	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports == 0)
		rte_exit(EXIT_FAILURE, "No Ethernet ports - bye\n");

	if (nb_ports > RTE_MAX_ETHPORTS)
		nb_ports = RTE_MAX_ETHPORTS;

	printf("available port %u\n ", nb_ports);
	fflush(stdout);
	
	rte_log_set_global_level(RTE_LOG_DEBUG);

	RTE_LCORE_FOREACH_WORKER(lcore_id) {
		printf("available lcore %u\n ", lcore_id);
	}
	/* Initialise each port */
	for (portid = 0; portid < 1; portid++) {
		/* init port */
		printf("Initializing port %u... ", (unsigned) portid);
		fflush(stdout);
		ret = rte_eth_dev_configure(portid, 1, TX_QUEUE, &port_conf);
		if (ret < 0)
			rte_exit(EXIT_FAILURE, "Cannot configure device: err=%d, port=%u\n",
				  ret, (unsigned) portid);

		/* init one RX queue */
		fflush(stdout);
		ret = rte_eth_rx_queue_setup(portid, 0, nb_rxd,
					     rte_eth_dev_socket_id(portid),
					     NULL,
					     l2fwd_pktmbuf_pool);
		if (ret < 0)
			rte_exit(EXIT_FAILURE, "rte_eth_rx_queue_setup:err=%d, port=%u\n",
				  ret, (unsigned) portid);

		/* init one TX queue on each port */
		fflush(stdout);
		for (i = 0; i < TX_QUEUE; i++) {
			ret = rte_eth_tx_queue_setup(portid, i, nb_txd,
					rte_eth_dev_socket_id(portid),
					NULL);
			if (ret < 0)
				rte_exit(EXIT_FAILURE, "rte_eth_tx_queue_setup:err=%d, port=%u\n",
					ret, (unsigned) portid);

		}

		/* Start device */
		ret = rte_eth_dev_start(portid);
		if (ret < 0)
			rte_exit(EXIT_FAILURE, "rte_eth_dev_start:err=%d, port=%u\n",
				  ret, (unsigned) portid);

		printf("done: \n");

		rte_eth_promiscuous_enable(portid);

	}


	printf("LAUNCHING RX\n");
	ret = rte_eal_remote_launch(rx, NULL, 2);
	if (ret)
		rte_exit(EXIT_FAILURE, "rx launch fail\n");

	for (tx_queue_id = 0; tx_queue_id < TX_QUEUE; tx_queue_id++) {
		printf("LAUNCHING TX at queue %d\n", tx_queue_id);
		ret = rte_eal_remote_launch(tx, (void *)&tx_queue_id, 3 + tx_queue_id);
		if (ret)
			rte_exit(EXIT_FAILURE, "tx launch fail\n");
	}

	char *line = NULL;
	size_t n;

//	while (getline(&line, &n, stdin) >= 0) {
	while (true) {	
		errno = 0;
//		new_microflows = strtoull(line, NULL, 0);
//		free(line);
		line = NULL;
	
		if (force_quit)
			break;
	
/*
		if (errno != ERANGE) {
			printf("new_microflows %llu\n", new_microflows);
			// XXX this should be atomic
			microflows = new_microflows;
		}
*/
	}
	for (portid = 0; portid < nb_ports; portid++) {
		printf("close port id %d\n", portid);
		rte_eth_dev_stop(portid);
		rte_eth_dev_close(portid);
	}
	return 0;
}
