# cURL with HTTP3

The Docker builadabale `curl` is compiled with  `BoringSSL` and `quiche` to with **HTTP3** support & without httpstat support.

Note: [curl + http3 manual](https://github.com/curl/curl/blob/master/docs/HTTP3.md#quiche-version)

## Usage

### Building

`docker build -t curl-http3 .`

### Versions

`docker run -it --rm curl-http3 curl -V`

```sh
curl 8.0.1-DEV (x86_64-pc-linux-musl) libcurl/8.0.1-DEV BoringSSL quiche/0.17.1
Release-Date: [unreleased]
Protocols: dict file ftp ftps gopher gophers http https imap imaps mqtt pop3 pop3s rtsp smb smbs smtp smtps telnet tftp
Features: alt-svc AsynchDNS HSTS HTTP3 HTTPS-proxy IPv6 Largefile NTLM NTLM_WB SSL threadsafe UnixSockets
```

`docker run -it --rm curl-http3 curl -IL https://daniel.haxx.se --http3`

Add `--verbose` for additional protocol level details.

```sh
❯ curl-http3 curl -IL https://daniel.haxx.se --http3

content-length: 6124
server: nginx/1.21.1
content-type: text/html
last-modified: Thu, 23 Mar 2023 09:19:22 GMT
etag: "17ec-5f78dc5b41b98"
cache-control: max-age=60
expires: Mon, 27 Mar 2023 11:22:02 GMT
strict-transport-security: max-age=31536000
via: 1.1 varnish, 1.1 varnish
accept-ranges: bytes
date: Fri, 31 Mar 2023 20:58:23 GMT
age: 0
x-served-by: cache-bma1640-BMA, cache-hhn-etou8220048-HHN
x-cache: HIT, HIT
x-cache-hits: 24, 1
x-timer: S1680296303.071683,VS0,VE34
vary: Accept-Encoding
alt-svc: h3=":443";ma=86400,h3-29=":443";ma=86400,h3-27=":443";ma=86400
```

## Additional Usage and Options

### qlog

qlog is a verbose JSON-based logging format specifically for QUIC and HTTP/3.

Can be enabled by setting the environment variable `QLOGDIR` as `QLOGDIR=<some-location>`, as an example:

```sh
docker run --volume $(pwd)/qlog:/srv -it --rm --env QLOGDIR=/srv curl-http3 curl -IL https://daniel.haxx.se --http3
```

### alt-svc

To use HTTP/3, add the --http3 parameter and ensure that support is enabled. This is achieved by initially loading the URL via HTTP/1.1 or HTTP/2 and receiving an alt-svc HTTP response header. curl allows you to save the alt-svc information in a cache file from the first request, enabling subsequent requests to load over HTTP/3 without explicitly setting the `--http3` flag. This approach better simulates the typical browser/client behavior.

```sh
docker run -it --rm curl-http3 sh -c "curl -IL https://daniel.haxx.se --alt-svc as.store; curl -IL https://daniel.haxx.se --alt-svc as.store; cat as.store"
```

This should show you a first request over HTTP/2 (or HTTP/1.1), followed by HTTP/3.

The contents of the `as.store` alt-svc cache file.

### tcpdump

Needs manually start and stop it before and after running curl. To be able to decrypt the QUIC-HTTP/3 traffic, you need to set the `SSLKEYLOGFILE` variable, which will be used to log the TLS keys.

To decrypt the traffic, set the "(Pre)-Master-Secret log filename" in `Preferences > Protocols > TLS` to the exported `tls_keys.txt` file.

```sh
docker run -it --rm --volume $(pwd)/pcaps:/srv --env SSLKEYLOGFILE=/srv/tls_keys.txt curl-http3 bash -c "tcpdump -w /srv/packets.pcap -i eth0 & sleep 1; curl -IL https://daniel.haxx.se --http3; sleep 2; pkill tcpdump; sleep 2"
```


