#ifndef COAKKA_HTTP_REQUEST_CONTROL_H
#define COAKKA_HTTP_REQUEST_CONTROL_H

#include <stdint.h>

/* Request lifetime at a successful route publication cut. Zero initialization
 * deliberately means UNKNOWN, never permission to free a handler. A terminal
 * response, completed shutdown, or zero active-request count is not this proof.
 * Session, callback, application metadata and user-held object references have
 * their own lifetimes; even QUIESCENT certifies only Core request captures. */
typedef uint32_t coakka_http_request_retirement_state_t;
#define COAKKA_HTTP_REQUEST_RETIREMENT_UNKNOWN UINT32_C(0)
#define COAKKA_HTTP_REQUEST_RETIREMENT_CAPTURED UINT32_C(1)
#define COAKKA_HTTP_REQUEST_RETIREMENT_QUIESCENT UINT32_C(2)
#define COAKKA_HTTP_REQUEST_RETIREMENT_STILL_ROUTABLE UINT32_C(3)
#define COAKKA_HTTP_REQUEST_RETIREMENT_NOT_APPLICABLE UINT32_C(4)

/* Observation and publication have separate outcomes. A published route may
 * coexist with an unavailable/timeout retirement observation. Retry a cold
 * observation; never resubmit route intent solely to obtain a lifetime proof. */
typedef uint32_t coakka_http_request_retirement_code_t;
#define COAKKA_HTTP_REQUEST_RETIREMENT_UNAVAILABLE UINT32_C(0)
#define COAKKA_HTTP_REQUEST_RETIREMENT_OBSERVED UINT32_C(1)
#define COAKKA_HTTP_REQUEST_RETIREMENT_INVALID_ARGUMENT UINT32_C(2)
#define COAKKA_HTTP_REQUEST_RETIREMENT_UNSUPPORTED UINT32_C(3)
#define COAKKA_HTTP_REQUEST_RETIREMENT_OUT_OF_MEMORY UINT32_C(4)
#define COAKKA_HTTP_REQUEST_RETIREMENT_CLOSED UINT32_C(5)
#define COAKKA_HTTP_REQUEST_RETIREMENT_BUSY UINT32_C(6)
#define COAKKA_HTTP_REQUEST_RETIREMENT_CONFLICT UINT32_C(7)
#define COAKKA_HTTP_REQUEST_RETIREMENT_EXPIRED UINT32_C(8)
#define COAKKA_HTTP_REQUEST_RETIREMENT_TIMEOUT UINT32_C(9)
#define COAKKA_HTTP_REQUEST_RETIREMENT_WAKEUP_FAILED UINT32_C(10)
#define COAKKA_HTTP_REQUEST_RETIREMENT_PUBLICATION_FAILED UINT32_C(11)
#define COAKKA_HTTP_REQUEST_RETIREMENT_OBSERVATION_FAILED UINT32_C(12)
#define COAKKA_HTTP_REQUEST_RETIREMENT_NOT_FOUND UINT32_C(13)
#define COAKKA_HTTP_REQUEST_RETIREMENT_SYSTEM_ERROR UINT32_C(14)

/* A bounded value issued by Core, not reconstructed from terminal events.
 * Sources are the request owners participating in this cut, not measured CPU
 * utilization. UNKNOWN may carry a partial count but never a complete proof.
 * QUIESCENT requires every source to have acknowledged the captured identity.
 * The proof remains tied to this publication; intentionally republishing an
 * old handler identity creates a new lifetime and invalidates that inference. */
typedef struct coakka_http_request_retirement {
  coakka_http_request_retirement_state_t state;
  coakka_http_request_retirement_code_t code;
  uint32_t quiescent_sources;
  uint32_t sources;
} coakka_http_request_retirement_t;

#endif
