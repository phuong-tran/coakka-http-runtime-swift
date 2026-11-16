#ifndef COAKKA_HTTP_EXECUTION_H
#define COAKKA_HTTP_EXECUTION_H

#include <stdint.h>

typedef uint32_t coakka_http_execution_mode_t;
#define COAKKA_HTTP_EXECUTION_DEFAULT UINT32_C(0) /* Output only; input absence is NULL. */
#define COAKKA_HTTP_EXECUTION_EXACT UINT32_C(1)
#define COAKKA_HTTP_EXECUTION_PREFER_SUPPORTED UINT32_C(2)

/* Construction-only C intent, copied synchronously. NULL selects Core defaults.
 * A supplied record requires sizeof(record), a known non-default mode, count
 * 1 or 2 and reserved == 0. EXACT refuses unsupported topology. PREFER_SUPPORTED
 * lets Core select one loop for typed CPU/facility/budget restrictions, but
 * never disables features or retries service creation after a failure.
 * Language connectors own their private profile; this is not an app-host knob.
 */
typedef struct coakka_http_execution_options {
  uint32_t struct_size;
  coakka_http_execution_mode_t mode;
  uint32_t event_loop_count;
  uint32_t reserved;
} coakka_http_execution_options_t;

typedef uint32_t coakka_http_execution_reason_t;
#define COAKKA_HTTP_EXECUTION_DEFAULTED UINT32_C(0)
#define COAKKA_HTTP_EXECUTION_EXACT_SELECTED UINT32_C(1)
#define COAKKA_HTTP_EXECUTION_PREFERRED_SELECTED UINT32_C(2)
#define COAKKA_HTTP_EXECUTION_FACILITY_RESTRICTED UINT32_C(3)
#define COAKKA_HTTP_EXECUTION_BUDGET_RESTRICTED UINT32_C(4)
#define COAKKA_HTTP_EXECUTION_CPU_RESTRICTED UINT32_C(5)
#define COAKKA_HTTP_EXECUTION_CPU_UNOBSERVED UINT32_C(6)

/* Immutable construction decision, not activity or CPU utilization. Read with
 * the containing instance's execution.observed; global queries have no decision.
 * requested_count == 0 only for DEFAULT. selected_count remains unchanged on
 * failed start, backend replacement and stop; active counts live below.
 */
typedef struct coakka_http_execution_selection {
  coakka_http_execution_mode_t requested_mode;
  uint32_t requested_count;
  uint32_t selected_count;
  coakka_http_execution_reason_t reason;
} coakka_http_execution_selection_t;

/* Cold, pointer-free execution facts issued by Core. These count HTTP event
 * loops, not application threads, selected CPUs, OS threads or CPU utilization.
 * observed == 0 means no instance was inspected (for example global info).
 * configured_event_loops is the accepted construction reservation and remains
 * stable across failed start and stop. Active loops are those whose Core
 * kernel is observed RUNNING or DRAINING; draining is a subset of active.
 * Failed loops are observed FAILED kernels, not the number of past failures.
 *
 * Each kernel state is sampled atomically in a bounded cold pass; the fields
 * describe that pass, not a simultaneous cross-thread barrier. The caller must
 * serialize lifecycle changes/destruction as required by the containing API.
 * A zero active count is not permission to free retained request/event leases.
 */
typedef struct coakka_http_execution_info {
  uint32_t configured_event_loops;
  uint32_t active_event_loops;
  uint32_t draining_event_loops;
  uint32_t failed_event_loops;
  uint8_t observed;
  uint8_t reserved[7];
} coakka_http_execution_info_t;

#endif
