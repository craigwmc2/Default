#!/bin/bash
set -e

OUT_DIR="/hls/${CAMERA_NAME}"
mkdir -p "$OUT_DIR"

echo "Starting HLS transcode for ${CAMERA_NAME} from ${RTSP_URL}"

exec ffmpeg -loglevel warning \
  -rtsp_transport tcp \
  -i "${RTSP_URL}" \
  -c:v copy \
  -an \
  -f hls \
  -hls_time 2 \
  -hls_list_size 6 \
  -hls_flags delete_segments+independent_segments \
  -hls_segment_filename "${OUT_DIR}/seg%03d.ts" \
  "${OUT_DIR}/stream.m3u8"
