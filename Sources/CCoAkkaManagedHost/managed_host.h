#define COAKKA_MANAGED_BUFFERED_ONLY 1
#ifndef COAKKA_HTTP_MANAGED_HOST_H
#define COAKKA_HTTP_MANAGED_HOST_H

#include "coakka/http/host.h"

#if defined(_WIN32)
#if defined(COAKKA_HTTP_MANAGED_BUILD)
#define COAKKA_MANAGED_API __declspec(dllexport)
#else
#define COAKKA_MANAGED_API __declspec(dllimport)
#endif
#else
#define COAKKA_MANAGED_API __attribute__((visibility("default")))
#endif

/* Private bridge for the connector integration slice. Each language serializes
 * calls on one owner. The Core service is the only transport state owner. */
typedef struct coakka_managed_host coakka_managed_host;

typedef struct coakka_managed_event {
  coakka_http_host_exchange_t exchange;
  uint32_t kind;
  coakka_http_host_bytes_t method;
  coakka_http_host_bytes_t target;
  coakka_http_host_bytes_t body;
  uint64_t sequence;
  uint64_t binding_id;
  uint32_t stream_trailers;
} coakka_managed_event;

/* Connector descriptors contain only synchronously borrowed values. Core owns
 * semantic validation and the accepted configuration. */
typedef struct coakka_managed_listener {
  uint16_t port;
  uint32_t protocol;
  uint32_t security;
  uint32_t multi_protocol;
  uint64_t credential_generation;
  coakka_http_host_bytes_t address;
  coakka_http_host_bytes_t credential_id;
  coakka_http_host_bytes_t certificate;
  coakka_http_host_bytes_t key;
  coakka_http_host_bytes_t trust_roots;
  uint32_t monitor_collection, monitor_categories;
} coakka_managed_listener;

typedef struct coakka_managed_monitor {
  uint64_t generation, sequence, admitted_requests, completed, failed, cancelled;
  uint8_t collecting, stale, partial;
} coakka_managed_monitor;

typedef struct coakka_managed_route {
  uint64_t route_id;
  uint64_t binding_id;
  coakka_http_host_bytes_t method;
  coakka_http_host_bytes_t pattern;
  uint64_t max_body_bytes;
  uint8_t body_policy;
  uint8_t accept_absent;
  uint8_t accept_other;
  uint8_t accept_form;
  uint8_t accept_multipart;
  uint8_t stream_request;
  uint8_t websocket;
} coakka_managed_route;

typedef struct coakka_managed_socket_event {
  coakka_http_host_websocket_t session;
  coakka_http_host_exchange_t origin;
  coakka_http_host_bytes_t data;
  uint32_t kind, close_code;
} coakka_managed_socket_event;

typedef struct coakka_managed_static_mount {
  coakka_http_host_bytes_t url_prefix, root, index, fallback, cache_control;
  uint8_t include_dotfiles;
} coakka_managed_static_mount;

typedef struct coakka_managed_file_authority {
  uint64_t id, max_file_bytes;
  coakka_http_host_bytes_t root;
  uint32_t max_active_files;
} coakka_managed_file_authority;

typedef struct coakka_managed_metadata {
  coakka_http_host_bytes_t scheme;
  coakka_http_host_bytes_t authority;
  uint64_t route_id;
  uint64_t route_generation;
  uint64_t binding_revision;
  uint32_t headers;
  uint32_t path_parameters;
  uint32_t query_parameters;
  uint32_t trailers;
  uint32_t body_delivery;
} coakka_managed_metadata;

typedef enum coakka_managed_field_kind {
  COAKKA_MANAGED_HEADER = 0,
  COAKKA_MANAGED_PATH_PARAMETER = 1,
  COAKKA_MANAGED_QUERY_PARAMETER = 2,
  COAKKA_MANAGED_TRAILER = 3,
  COAKKA_MANAGED_STREAM_TRAILER = 4,
} coakka_managed_field_kind;

COAKKA_MANAGED_API int32_t coakka_managed_create_buffered(
    const coakka_managed_listener *listener, const coakka_managed_route *routes,
    uint32_t count, coakka_managed_host **out, uint32_t *failed_route);
COAKKA_MANAGED_API int32_t coakka_managed_create_with_files(
    const coakka_managed_listener *listener, const coakka_managed_route *routes,
    uint32_t count, const coakka_managed_static_mount *mounts,
    uint32_t mount_count, const coakka_managed_file_authority *authorities,
    uint32_t authority_count, coakka_managed_host **out, uint32_t *failed_route);
COAKKA_MANAGED_API int32_t coakka_managed_start_with_issue(
    coakka_managed_host *host, coakka_http_host_issue_t *issue);
COAKKA_MANAGED_API int32_t coakka_managed_monitor_snapshot(
    coakka_managed_host *host, coakka_managed_monitor *out);
/* Metadata borrows a REQUEST lease. Indexed spans also support streamed
 * trailers on the separate REQUEST_TRAILERS lease. */
COAKKA_MANAGED_API int32_t coakka_managed_metadata_read(
    const coakka_managed_host *host, coakka_managed_metadata *out);
COAKKA_MANAGED_API int32_t coakka_managed_field_read(
    const coakka_managed_host *host, uint32_t kind, uint32_t index,
    coakka_http_host_bytes_t *name, coakka_http_host_bytes_t *value,
    uint8_t *has_value);
COAKKA_MANAGED_API int32_t coakka_managed_respond_buffered(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    uint32_t status, const uint8_t *body, size_t length,
    const coakka_http_host_header_t *headers, uint32_t header_count);
COAKKA_MANAGED_API int32_t coakka_managed_respond_file(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    uint32_t status, uint64_t authority, coakka_http_host_bytes_t path,
    const coakka_http_host_header_t *headers, uint32_t header_count);
COAKKA_MANAGED_API int32_t coakka_managed_rebind(
    coakka_managed_host *host, uint64_t activation_id, uint64_t route_generation,
    uint64_t route_id, uint64_t binding_revision, uint64_t new_binding_id,
    coakka_http_host_rebind_outcome_t *outcome);

/* These calls borrow inputs until return. Core owns accepted response bytes. */
COAKKA_MANAGED_API int32_t coakka_managed_start_response_stream(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    uint32_t status, const coakka_http_host_header_t *headers,
    uint32_t header_count);
COAKKA_MANAGED_API int32_t coakka_managed_write_response_stream(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    const uint8_t *body, size_t length);
COAKKA_MANAGED_API int32_t coakka_managed_finish_response_stream(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    const coakka_http_host_header_t *trailers, uint32_t trailer_count);
COAKKA_MANAGED_API int32_t coakka_managed_start_sse(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    const coakka_http_host_header_t *headers, uint32_t header_count);
COAKKA_MANAGED_API int32_t coakka_managed_write_sse(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    coakka_http_host_bytes_t data, coakka_http_host_bytes_t event_type,
    coakka_http_host_bytes_t id, uint64_t retry_ms, uint8_t has_retry);
COAKKA_MANAGED_API int32_t coakka_managed_accept_websocket(
    coakka_managed_host *, coakka_http_host_exchange_t, coakka_http_host_bytes_t);
COAKKA_MANAGED_API int32_t coakka_managed_take_websocket(
    coakka_managed_host *, uint64_t, coakka_managed_socket_event *);
COAKKA_MANAGED_API int32_t coakka_managed_release_websocket(coakka_managed_host *);
COAKKA_MANAGED_API int32_t coakka_managed_send_websocket(
    coakka_managed_host *, coakka_http_host_websocket_t, uint32_t, coakka_http_host_bytes_t);
COAKKA_MANAGED_API int32_t coakka_managed_close_websocket(
    coakka_managed_host *, coakka_http_host_websocket_t, uint32_t, coakka_http_host_bytes_t);

/* Swift imports enum constants but does not import the Core literal macros. */
enum {
  COAKKA_MANAGED_OK = COAKKA_HTTP_HOST_OK,
  COAKKA_MANAGED_INVALID_ARGUMENT = COAKKA_HTTP_HOST_INVALID_ARGUMENT,
  COAKKA_MANAGED_CLOSED = COAKKA_HTTP_HOST_CLOSED,
  COAKKA_MANAGED_TIMEOUT = COAKKA_HTTP_HOST_TIMEOUT,
  COAKKA_MANAGED_STALE_EXCHANGE = COAKKA_HTTP_HOST_STALE_EXCHANGE,
  COAKKA_MANAGED_UNSUPPORTED = COAKKA_HTTP_HOST_UNSUPPORTED,
  COAKKA_MANAGED_REQUEST = COAKKA_HTTP_HOST_REQUEST,
  COAKKA_MANAGED_REQUEST_DATA = COAKKA_HTTP_HOST_REQUEST_DATA,
  COAKKA_MANAGED_REQUEST_TRAILERS = COAKKA_HTTP_HOST_REQUEST_TRAILERS,
  COAKKA_MANAGED_REQUEST_END = COAKKA_HTTP_HOST_REQUEST_END,
  COAKKA_MANAGED_BODY_INLINE = COAKKA_HTTP_HOST_REQUEST_BODY_INLINE,
  COAKKA_MANAGED_BODY_STREAM = COAKKA_HTTP_HOST_REQUEST_BODY_STREAM,
  COAKKA_MANAGED_CANCELLED = COAKKA_HTTP_HOST_REQUEST_CANCELLED,
  COAKKA_MANAGED_RESPONSE_WRITABLE = COAKKA_HTTP_HOST_RESPONSE_WRITABLE,
  COAKKA_MANAGED_TERMINAL = COAKKA_HTTP_HOST_REQUEST_TERMINAL,
  COAKKA_MANAGED_HTTP_1_1 = COAKKA_HTTP_HOST_MULTI_LISTENER_HTTP_1_1,
  COAKKA_MANAGED_HTTP_2 = COAKKA_HTTP_HOST_MULTI_LISTENER_HTTP_2,
  COAKKA_MANAGED_HTTP_3 = COAKKA_HTTP_HOST_MULTI_LISTENER_HTTP_3,
  COAKKA_MANAGED_DRAIN_PENDING = COAKKA_HTTP_HOST_DRAIN_PENDING,
  COAKKA_MANAGED_DRAIN_COMPLETE = COAKKA_HTTP_HOST_DRAIN_COMPLETE,
  COAKKA_MANAGED_DRAIN_EXPIRED = COAKKA_HTTP_HOST_DRAIN_EXPIRED,
  COAKKA_MANAGED_DRAIN_ABORTED = COAKKA_HTTP_HOST_DRAIN_ABORTED,
};

COAKKA_MANAGED_API uint32_t coakka_managed_abi(void);
#ifndef COAKKA_MANAGED_BUFFERED_ONLY
COAKKA_MANAGED_API int32_t coakka_managed_create(const uint8_t *path,
                                                 size_t length,
                                                 coakka_managed_host **out);
/* These UTF-8 path spans are borrowed only during creation. The V1 profile
 * always uses TLS; certificate errors are propagated from Core. */
COAKKA_MANAGED_API int32_t coakka_managed_create_v1(
    const uint8_t *path, size_t length, const uint8_t *certificate,
    size_t certificate_length, const uint8_t *key, size_t key_length,
    coakka_managed_host **out);
#endif
/* One Core snapshot; outputs are written only on success. */
COAKKA_MANAGED_API int32_t coakka_managed_listener_v1_state(
    coakka_managed_host *host, uint16_t *port, uint32_t *admitting_protocols);
#ifndef COAKKA_MANAGED_BUFFERED_ONLY
COAKKA_MANAGED_API int32_t coakka_managed_start(coakka_managed_host *host);
#endif

COAKKA_MANAGED_API int32_t coakka_managed_port(coakka_managed_host *host,
                                               uint16_t *port);
/* Read waits are limited to 1000 ms. Borrowed spans remain valid until release.
 * The connector copies them before returning to its caller. Any retained
 * event is also released during close. */
COAKKA_MANAGED_API int32_t coakka_managed_take(coakka_managed_host *host,
                                               uint64_t timeout_ms,
                                               coakka_managed_event *event);
COAKKA_MANAGED_API int32_t coakka_managed_release(coakka_managed_host *host);
#ifndef COAKKA_MANAGED_BUFFERED_ONLY
COAKKA_MANAGED_API int32_t coakka_managed_respond(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    uint32_t status, const uint8_t *body, size_t length);

#endif
COAKKA_MANAGED_API int32_t coakka_managed_cancelled(
    coakka_managed_host *host, coakka_http_host_exchange_t exchange,
    uint8_t *cancelled);
COAKKA_MANAGED_API int32_t
coakka_managed_begin_drain(coakka_managed_host *host);
COAKKA_MANAGED_API int32_t coakka_managed_wait_drained(
    coakka_managed_host *host, uint64_t timeout_ms, uint32_t *state);
COAKKA_MANAGED_API int32_t coakka_managed_stop(coakka_managed_host *host);
COAKKA_MANAGED_API int32_t coakka_managed_close(coakka_managed_host **host);

#endif
