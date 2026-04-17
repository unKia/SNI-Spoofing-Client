#import <Foundation/Foundation.h>
#import <pcap/pcap.h>

#ifdef __cplusplus
extern "C" {
#endif

pcap_t *sni_pcap_open_live(const char *device, int snaplen, int promisc, int to_ms, char *errbuf, size_t errbuf_size);
int sni_pcap_set_filter(pcap_t *handle, const char *expression, int optimize, bpf_u_int32 netmask, char *errbuf, size_t errbuf_size);
int sni_pcap_set_nonblock(pcap_t *handle, int nonblock, char *errbuf, size_t errbuf_size);
int sni_pcap_datalink(pcap_t *handle);
int sni_pcap_next_packet(pcap_t *handle, unsigned char **data, int *len, char *errbuf, size_t errbuf_size);
void sni_pcap_free_packet(unsigned char *data);
int sni_pcap_inject(pcap_t *handle, const unsigned char *data, int len, char *errbuf, size_t errbuf_size);
void sni_pcap_breakloop(pcap_t *handle);
void sni_pcap_close(pcap_t *handle);

#ifdef __cplusplus
}
#endif
