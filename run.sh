JVMPath32bit=`alternatives --display java | grep family | grep i386 | awk '{print $1}'`
JVMPath64bit=`alternatives --display java | grep family | grep x86_64 | awk '{print $1}'`


# set the java version used based on JENKINS_JVM_ARCH
if [ -z $JENKINS_JVM_ARCH  ]; then
    echo "Using 64 bit Java since JENKINS_JVM_ARCH is not set (historic setting)"
    alternatives --set java $JVMPath64bit
elif [ "${JENKINS_JVM_ARCH}" == "x86_64"  ]; then
    echo "64 bit Java explicitly set in JENKINS_JVM_ARCH"
    alternatives --set java $JVMPath64bit
else
    echo "JENKINS_JVM_ARCH is set to ${JENKINS_JVM_ARCH} so using 32 bit Java"
    alternatives --set java $JVMPath32bit
    export MALLOC_ARENA_MAX=1
fi

CONTAINER_MEMORY_IN_BYTES=`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`
DEFAULT_MEMORY_CEILING=$((2**40-1))
if [ "${CONTAINER_MEMORY_IN_BYTES}" -lt "${DEFAULT_MEMORY_CEILING}" ]; then

    if [ -z $CONTAINER_HEAP_PERCENT ]; then
        CONTAINER_HEAP_PERCENT=0.50
    fi

    CONTAINER_MEMORY_IN_MB=$((${CONTAINER_MEMORY_IN_BYTES}/1024**2))
    #if machine has 4GB or less, meaning max heap of 2GB given current default, force use of 32bit to save space unless user
    #specifically want to force 64bit
    HEAP_LIMIT_FOR_32BIT=$((2**32-1))
    HEAP_LIMIT_FOR_32BIT_IN_MB=$((${HEAP_LIMIT_FOR_32BIT}/1024**2))
    CONTAINER_HEAP_MAX=$(echo "${CONTAINER_MEMORY_IN_MB} ${CONTAINER_HEAP_PERCENT}" | awk '{ printf "%d", $1 * $2 }')
    if [[ -z $JENKINS_JVM_ARCH && "${CONTAINER_HEAP_MAX}" -lt "${HEAP_LIMIT_FOR_32BIT_IN_MB}"  ]]; then
      echo "max heap in MB is ${CONTAINER_HEAP_MAX} and 64 bit was not explicitly set so using 32 bit Java"
      alternatives --set java $JVMPath32bit
      export MALLOC_ARENA_MAX=1
    fi

    JAVA_MAX_HEAP_PARAM="-Xmx${CONTAINER_HEAP_MAX}m"
    if [ -z $CONTAINER_INITIAL_PERCENT ]; then
      CONTAINER_INITIAL_PERCENT=0.07
    fi
    CONTAINER_INITIAL_HEAP=$(echo "${CONTAINER_HEAP_MAX} ${CONTAINER_INITIAL_PERCENT}" | awk '{ printf "%d", $1 * $2 }')
    JAVA_INITIAL_HEAP_PARAM="-Xms${CONTAINER_INITIAL_HEAP}m"
fi

if [ -z "$JAVA_GC_OPTS" ]; then
    # We no longer set MaxMetaspaceSize because the JVM should expand metaspace until it reaches the container limit.
    # See http://hg.openjdk.java.net/jdk8u/jdk8u/hotspot/file/4dd24f4ca140/src/share/vm/memory/metaspace.cpp#l1470
    JAVA_GC_OPTS="-XX:+UseParallelGC -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90"
fi

if [ ! -z "${USE_JAVA_DIAGNOSTICS}" ]; then
    JAVA_DIAGNOSTICS="-XX:NativeMemoryTracking=summary -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+UnlockDiagnosticVMOptions"
fi

if [ ! -z "${CONTAINER_CORE_LIMIT}" ]; then
    JAVA_CORE_LIMIT="-XX:ParallelGCThreads=${CONTAINER_CORE_LIMIT} -Djava.util.concurrent.ForkJoinPool.common.parallelism=${CONTAINER_CORE_LIMT} -XX:CICompilerCount=2"
fi

if [ -z "${JAVA_OPTS}" ]; then
    JAVA_OPTS="-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Dsun.zip.disableMemoryMapping=true"
fi

echo "should look something like:"
echo "java -XX:+UseParallelGC -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Xms17m -Xmx256m -Duser.home=/var/lib/jenkins -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Dsun.zip.disableMemoryMapping=true -Dfile.encoding=UTF8 -jar /usr/lib/jenkins/jenkins.war"
echo "java $JAVA_GC_OPTS $JAVA_INITIAL_HEAP_PARAM $JAVA_MAX_HEAP_PARAM -Duser.home=${HOME} $JAVA_CORE_LIMIT $JAVA_DIAGNOSTICS $JAVA_OPTS -Dfile.encoding=UTF8 -jar /usr/lib/jenkins/jenkins.war $JENKINS_OPTS $JENKINS_ACCESSLOG"
# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
   exec java $JAVA_GC_OPTS $JAVA_INITIAL_HEAP_PARAM $JAVA_MAX_HEAP_PARAM -Duser.home=${HOME} $JAVA_CORE_LIMIT $JAVA_DIAGNOSTICS $JAVA_OPTS -Dfile.encoding=UTF8 -jar /usr/lib/jenkins/jenkins.war $JENKINS_OPTS $JENKINS_ACCESSLOG "$@"
fi

# As argument is not jenkins, assume user want to run his own process, for sample a `bash` shell to explore this image
exec "$@"
