#!/bin/bash
#!/bin/bash
for i in {1..100}
do
  docker kill node${i}
done
