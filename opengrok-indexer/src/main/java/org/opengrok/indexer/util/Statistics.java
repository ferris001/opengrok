/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * See LICENSE.txt included in this distribution for the specific
 * language governing permissions and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at LICENSE.txt.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2014, 2018 Oracle and/or its affiliates. All rights reserved.
 */

package org.opengrok.indexer.util;

import java.time.Duration;
import java.time.Instant;
import java.util.logging.Level;
import java.util.logging.Logger;
import static org.opengrok.indexer.util.StringUtils.getReadableTime;

public class Statistics {

    private final Instant startTime;

    public Statistics() {
      startTime = Instant.now();
  }

    /**
     * log a message along with how much time it took since the constructor was called.
     * @param logger logger instance
     * @param logLevel log level
     * @param msg message string
     */
    public void report(Logger logger, Level logLevel, String msg) {
        String timeStr = StringUtils.getReadableTime(Duration.between(startTime, Instant.now()).toMillis());
        logger.log(logLevel, msg + " (took {0})", timeStr);
    }

    /**
     * log a message along with how much time it took since the constructor was called.
     * The log level is {@code INFO}.
     * @param logger logger instance
     * @param msg message string
     */
    public void report(Logger logger, String msg) {
        report(logger, Level.INFO, msg);
    }

    /**
     * log a message along with how much time and memory it took since the constructor was called.
     * The message will be logged with the {@code INFO} level.
     * @param logger logger instance
     */
    public void report(Logger logger) {
        logger.log(Level.INFO, "Total time: {0}",
                getReadableTime(Duration.between(startTime, Instant.now()).toMillis()));

        System.gc();
        Runtime r = Runtime.getRuntime();
        long mb = 1024L * 1024;
        logger.log(Level.INFO, "Final Memory: {0}M/{1}M",
                new Object[]{(r.totalMemory() - r.freeMemory()) / mb, r.totalMemory() / mb});
    }
}
