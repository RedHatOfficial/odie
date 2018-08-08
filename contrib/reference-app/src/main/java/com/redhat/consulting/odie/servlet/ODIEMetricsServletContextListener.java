package com.redhat.consulting.odie.servlet;

import com.codahale.metrics.MetricRegistry;
import com.codahale.metrics.health.HealthCheckRegistry;
import com.codahale.metrics.servlets.HealthCheckServlet;
import com.codahale.metrics.servlets.MetricsServlet;
import com.redhat.consulting.odie.checks.AMQHealthCheck;

import javax.servlet.Servlet;
import javax.servlet.annotation.WebListener;
import java.rmi.registry.Registry;

@WebListener
public class ODIEMetricsServletContextListener extends MetricsServlet.ContextListener {

  final static MetricRegistry METRIC_REGISTRY = new MetricRegistry();

  @Override
  protected MetricRegistry getMetricRegistry() {
    return METRIC_REGISTRY;
  }
}
