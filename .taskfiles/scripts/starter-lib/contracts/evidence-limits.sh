#!/usr/bin/env bash
# Resource limits for retained release evidence. These are availability controls,
# not publisher identity or trust policy.

: "${STARTER_EVIDENCE_MAX_REACHABLE_OBJECTS:=100000}"
: "${STARTER_EVIDENCE_MAX_OBJECT_BYTES:=67108864}"
: "${STARTER_EVIDENCE_MAX_PACK_BYTES:=268435456}"
: "${STARTER_EVIDENCE_MAX_RETAINED_BYTES:=536870912}"

starter_evidence_limits() {
	jq -cn \
		--argjson objects "${STARTER_EVIDENCE_MAX_REACHABLE_OBJECTS}" \
		--argjson object_bytes "${STARTER_EVIDENCE_MAX_OBJECT_BYTES}" \
		--argjson pack_bytes "${STARTER_EVIDENCE_MAX_PACK_BYTES}" \
		--argjson retained_bytes "${STARTER_EVIDENCE_MAX_RETAINED_BYTES}" \
		'{max_reachable_objects:$objects,max_object_bytes:$object_bytes,max_pack_bytes:$pack_bytes,max_retained_bytes:$retained_bytes}'
}
