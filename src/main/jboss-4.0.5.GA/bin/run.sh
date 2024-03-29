#!/bin/sh
### ====================================================================== ###
##                                                                          ##
##  JBoss Bootstrap Script                                                  ##
##                                                                          ##
### ====================================================================== ###

### $Id: run.sh 57514 2006-10-09 18:16:00Z dimitris@jboss.org $ ###

DIRNAME=`dirname $0`
PROGNAME=`basename $0`
GREP="grep"

# Use the maximum available, or set MAX_FD != -1 to use that
MAX_FD="maximum"

#
# Helper to complain.
#
warn() {
    echo "${PROGNAME}: $*"
}

#
# Helper to puke.
#
die() {
    warn $*
    exit 1
}

# OS specific support (must be 'true' or 'false').
cygwin=false;
darwin=false;
case "`uname`" in
    CYGWIN*)
        cygwin=true
        ;;

    Darwin*)
        darwin=true
        ;;
esac

# Read an optional running configuration file
if [ "x$RUN_CONF" = "x" ]; then
    RUN_CONF="$DIRNAME/run.conf"
fi
if [ -r "$RUN_CONF" ]; then
    . "$RUN_CONF"
fi

# For Cygwin, ensure paths are in UNIX format before anything is touched
if $cygwin ; then
    [ -n "$JBOSS_HOME" ] &&
        JBOSS_HOME=`cygpath --unix "$JBOSS_HOME"`
    [ -n "$JAVA_HOME" ] &&
        JAVA_HOME=`cygpath --unix "$JAVA_HOME"`
    [ -n "$JAVAC_JAR" ] &&
        JAVAC_JAR=`cygpath --unix "$JAVAC_JAR"`
fi

# Setup JBOSS_HOME
if [ "x$JBOSS_HOME" = "x" ]; then
    # get the full path (without any relative bits)
    JBOSS_HOME=`cd $DIRNAME/..; pwd`
fi
export JBOSS_HOME

# Increase the maximum file descriptors if we can
if [ "$cygwin" = "false" ]; then
    if [ "$darwin" = "true" ]; then
      MAX_FD_LIMIT=`sysctl -n kern.maxfilesperproc`
    else
      MAX_FD_LIMIT=`ulimit -H -n`
    fi
    if [ $? -eq 0 ]; then
	if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ]; then
	    # use the system max
	    MAX_FD="$MAX_FD_LIMIT"
	fi

	ulimit -n $MAX_FD
	if [ $? -ne 0 ]; then
	    warn "Could not set maximum file descriptor limit: $MAX_FD"
	fi
    else
	warn "Could not query system maximum file descriptor limit: $MAX_FD_LIMIT"
    fi
fi

# Setup the JVM
if [ "x$JAVA" = "x" ]; then
    if [ "x$JAVA_HOME" != "x" ]; then
	JAVA="$JAVA_HOME/bin/java"
    else
	JAVA="java"
    fi
fi

# Setup the classpath
runjar="$JBOSS_HOME/bin/run.jar"
if [ ! -f "$runjar" ]; then
    die "Missing required file: $runjar"
fi
JBOSS_BOOT_CLASSPATH="$runjar"

# Include the JDK javac compiler for JSP pages. The default is for a Sun JDK
# compatible distribution which JAVA_HOME points to
if [ "x$JAVAC_JAR" = "x" ]; then
    JAVAC_JAR="$JAVA_HOME/lib/tools.jar"
fi
if [ ! -f "$JAVAC_JAR" ]; then
   # MacOSX does not have a seperate tools.jar
   if [ "$darwin" != "true" ]; then
      warn "Missing file: $JAVAC_JAR"
      warn "Unexpected results may occur.  Make sure JAVA_HOME points to a JDK and not a JRE."
   fi
fi

if [ "x$JBOSS_CLASSPATH" = "x" ]; then
    JBOSS_CLASSPATH="$JBOSS_BOOT_CLASSPATH:$JAVAC_JAR"
else
    JBOSS_CLASSPATH="$JBOSS_CLASSPATH:$JBOSS_BOOT_CLASSPATH:$JAVAC_JAR"
fi

# If -server not set in JAVA_OPTS, set it, if supported
SERVER_SET=`echo $JAVA_OPTS | $GREP "\-server"`
if [ "x$SERVER_SET" = "x" ]; then

    # Check for SUN(tm) JVM w/ HotSpot support
    if [ "x$HAS_HOTSPOT" = "x" ]; then
	HAS_HOTSPOT=`"$JAVA" -version 2>&1 | $GREP -i HotSpot`
    fi

    # Enable -server if we have Hotspot, unless we can't
    if [ "x$HAS_HOTSPOT" != "x" ]; then
	# MacOS does not support -server flag
	if [ "$darwin" != "true" ]; then
	    JAVA_OPTS="-server $JAVA_OPTS"
	fi
    fi
fi

# Setup JBoss sepecific properties
JAVA_OPTS="-Dprogram.name=$PROGNAME $JAVA_OPTS"

# Setup the java endorsed dirs
JBOSS_ENDORSED_DIRS="$JBOSS_HOME/lib/endorsed"

# For Cygwin, switch paths to Windows format before running java
if $cygwin; then
    JBOSS_HOME=`cygpath --path --windows "$JBOSS_HOME"`
    JAVA_HOME=`cygpath --path --windows "$JAVA_HOME"`
    JBOSS_CLASSPATH=`cygpath --path --windows "$JBOSS_CLASSPATH"`
    JBOSS_ENDORSED_DIRS=`cygpath --path --windows "$JBOSS_ENDORSED_DIRS"`
fi

# Default to 8081 for jboss.web.port if not set
WEB_PORT_SET=`echo $JAVA_OPTS | $GREP "\-Djboss.web.port="`
if [ "x$WEB_PORT_SET" = "x" ]; then
  JAVA_OPTS="$JAVA_OPTS -Djboss.web.port=8081"
fi

# Default to 9093 for jboss.jms.port if not set
JMS_PORT_SET=`echo $JAVA_OPTS | $GREP "\-Djboss.jms.port="`
if [ "x$JMS_PORT_SET" = "x" ]; then
  JAVA_OPTS="$JAVA_OPTS -Djboss.jms.port=9093"
fi

# Display our environment
echo "========================================================================="
echo ""
echo "  JBoss Bootstrap Environment"
echo ""
echo "  JBOSS_HOME: $JBOSS_HOME"
echo ""
echo "  JAVA: $JAVA"
echo ""
echo "  JAVA_OPTS: $JAVA_OPTS"
echo ""
echo "  CLASSPATH: $JBOSS_CLASSPATH"
echo ""
echo "========================================================================="
echo ""

while true; do
   if [ "x$LAUNCH_JBOSS_IN_BACKGROUND" = "x" ]; then

      JBOSS_PID="$$"
      JBOSS_PID_DIR=${JBOSS_HOME}/server/default/tmp
      JBOSS_PID_FILE=${JBOSS_PID_DIR}/run.pid
      if [ ! -e "${JBOSS_PID_DIR}" ]; then
          mkdir -p "${JBOSS_PID_DIR}"
      fi
      echo "${JBOSS_PID}" > ${JBOSS_PID_FILE}
      echo "Process PID ${JBOSS_PID} written to ${JBOSS_PID_FILE}"

      cleanup() {
          echo "JBoss cleanup"
          if [ -e $JBOSS_PID_FILE ]; then
              echo "Removing ${JBOSS_PID_FILE}"
              rm ${JBOSS_PID_FILE}
          fi
      }

      trap cleanup HUP
      trap cleanup INT
      trap cleanup QUIT
      trap cleanup TERM

      # Execute the JVM in the foreground
      "$JAVA" $JAVA_OPTS \
         -Djava.endorsed.dirs="$JBOSS_ENDORSED_DIRS" \
         -classpath "$JBOSS_CLASSPATH" \
         org.jboss.Main "$@"
      JBOSS_STATUS=$?

      echo "JBoss exited with status $JBOSS_STATUS"
      cleanup

      exit ${JBOSS_STATUS}
   else
      # Execute the JVM in the background
      "$JAVA" $JAVA_OPTS \
         -Djava.endorsed.dirs="$JBOSS_ENDORSED_DIRS" \
         -classpath "$JBOSS_CLASSPATH" \
         org.jboss.Main "$@" &
      JBOSS_PID=$!
      # Trap common signals and relay them to the jboss process
      trap "kill -HUP  $JBOSS_PID" HUP
      trap "kill -TERM $JBOSS_PID" INT
      trap "kill -QUIT $JBOSS_PID" QUIT
      trap "kill -PIPE $JBOSS_PID" PIPE
      trap "kill -TERM $JBOSS_PID" TERM
      # Wait until the background process exits
      WAIT_STATUS=0
      while [ "$WAIT_STATUS" -ne 127 ]; do
         JBOSS_STATUS=$WAIT_STATUS
         wait $JBOSS_PID 2>/dev/null
         WAIT_STATUS=$?
      done
   fi
   # If restart doesn't work, check you are running JBossAS 4.0.4+
   #    http://jira.jboss.com/jira/browse/JBAS-2483
   # or the following if you're running Red Hat 7.0
   #    http://developer.java.sun.com/developer/bugParade/bugs/4465334.html   
   if [ $JBOSS_STATUS -eq 10 ]; then
      echo "Restarting JBoss..."
   else
      exit $JBOSS_STATUS
   fi
done

