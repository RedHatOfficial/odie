package com.redhat.consulting.odie.checks;

import com.codahale.metrics.health.HealthCheck;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.naming.Context;
import javax.naming.InitialContext;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.Statement;

public class DBHealthCheck extends HealthCheck {

  private static final Logger logger = LoggerFactory.getLogger(DBHealthCheck.class);


  @Override
  protected Result check() throws Exception {
    return (checkHealth()) ? Result.healthy() : Result.unhealthy("");
  }

  public boolean checkHealth() {
    String dsjndi = "java:jboss/datasources/TestPostgreSQLDS";

    try {
      Context ctx = new InitialContext();
      DataSource ds = (DataSource)ctx.lookup(dsjndi);
      Connection conn = null;
      Statement st = null;
      conn = ds.getConnection();
      st = conn.createStatement();
      st.executeQuery("SELECT 1;");
      st.close();
      conn.close();
      return true;
    } catch (Exception e) {
      logger.error(e.toString());
      return false;
    }
  }
}
