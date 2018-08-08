package com.redhat.consulting.odie.servlet;

import com.codahale.metrics.health.HealthCheckRegistry;
import com.codahale.metrics.servlets.AdminServlet;
import com.redhat.consulting.odie.checks.AMQHealthCheck;

import javax.servlet.annotation.WebServlet;

@WebServlet("/metrics/*")
public class ODIEAdminServlet extends AdminServlet {

}
