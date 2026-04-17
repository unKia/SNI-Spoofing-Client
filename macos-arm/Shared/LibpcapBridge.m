#import "LibpcapBridge.h"

#include <stdlib.h>
#include <string.h>

static void sni_write_error(char *buffer, size_t size, const char *message) {
    if (buffer == NULL || size == 0) {
        return;
    }
    if (message == NULL) {
        buffer[0] = '\0';
        return;
    }
    snprintf(buffer, size, "%s", message);
}

pcap_t *sni_pcap_open_live(const char *device, int snaplen, int promisc, int to_ms, char *errbuf, size_t errbuf_size) {
    pcap_t *handle = pcap_open_live(device, snaplen, promisc, to_ms, errbuf);
    if (handle == NULL) {
        sni_write_error(errbuf, errbuf_size, "pcap_open_live failed");
        return NULL;
    }
    return handle;
}

int sni_pcap_set_filter(pcap_t *handle, const char *expression, int optimize, bpf_u_int32 netmask, char *errbuf, size_t errbuf_size) {
    struct bpf_program program;
    if (pcap_compile(handle, &program, expression, optimize, netmask) != 0) {
        sni_write_error(errbuf, errbuf_size, pcap_geterr(handle));
        return -1;
    }

    if (pcap_setfilter(handle, &program) != 0) {
        sni_write_error(errbuf, errbuf_size, pcap_geterr(handle));
        pcap_freecode(&program);
        return -1;
    }

    pcap_freecode(&program);
    return 0;
}

int sni_pcap_set_nonblock(pcap_t *handle, int nonblock, char *errbuf, size_t errbuf_size) {
    if (pcap_setnonblock(handle, nonblock, errbuf) != 0) {
        sni_write_error(errbuf, errbuf_size, pcap_geterr(handle));
        return -1;
    }
    return 0;
}

int sni_pcap_datalink(pcap_t *handle) {
    return pcap_datalink(handle);
}

int sni_pcap_next_packet(pcap_t *handle, unsigned char **data, int *len, char *errbuf, size_t errbuf_size) {
    struct pcap_pkthdr *header = NULL;
    const u_char *packet = NULL;
    int result = pcap_next_ex(handle, &header, &packet);
    if (result == 1) {
        *len = (int)header->caplen;
        *data = malloc(header->caplen);
        if (*data == NULL) {
            sni_write_error(errbuf, errbuf_size, "malloc failed");
            return -1;
        }
        memcpy(*data, packet, header->caplen);
        return 1;
    }
    if (result == 0) {
        return 0;
    }
    if (result == -2) {
        return -2;
    }
    sni_write_error(errbuf, errbuf_size, pcap_geterr(handle));
    return -1;
}

void sni_pcap_free_packet(unsigned char *data) {
    free(data);
}

int sni_pcap_inject(pcap_t *handle, const unsigned char *data, int len, char *errbuf, size_t errbuf_size) {
    int written = (int)pcap_inject(handle, data, (size_t)len);
    if (written < 0) {
        sni_write_error(errbuf, errbuf_size, pcap_geterr(handle));
    }
    return written;
}

void sni_pcap_breakloop(pcap_t *handle) {
    pcap_breakloop(handle);
}

void sni_pcap_close(pcap_t *handle) {
    pcap_close(handle);
}
