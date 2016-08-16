# fluent-plugin-google-cloud-storage

[original : https://badge.fury.io/rb/fluent-plugin-google-cloud-storage](https://badge.fury.io/rb/fluent-plugin-google-cloud-storage)


for new google api client

## Configuration

### Examples

#### Complete Example

    # tail
    <source>
      type tail
      format none
      path /tmp/test.log
      pos_file /var/log/td-agent/test.pos
      tag tail.test
    </source>

    # post to GCS
    <match tail.test>
      type google_cloud_storage
      email xxx.xxx.com
      private_key_path /etc/td-agent/My_First_Project-xxx.p12
      bucket_id test_bucket
      path tail.test/%Y/%m/%d/%H/${hostname}/${chunk_id}.log.gz
      buffer_path /var/log/td-agent/buffer/tail.test
      # flush_interval 600s
      buffer_chunk_limit 128m
      time_slice_wait 300s
      compress gzip
    </match>

## TODO

* docs?
* patches welcome!

## Copyright

* Copyright (c) 2014- Hsiu-Fan Wang (hfwang@porkbuns.net)
* License
  * Apache License, Version 2.0
