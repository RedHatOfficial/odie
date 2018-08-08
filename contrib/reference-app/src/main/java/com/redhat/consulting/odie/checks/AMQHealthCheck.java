package com.redhat.consulting.odie.checks;

import com.codahale.metrics.health.HealthCheck;
import com.redhat.consulting.odie.exceptions.BrokerException;
import com.redhat.consulting.odie.mdb.ODIEQueueMDB;
import com.redhat.consulting.odie.servlet.ODIEHealthCheckServletContextListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.annotation.Resource;
import javax.enterprise.context.ApplicationScoped;
import javax.inject.Named;
import javax.jms.*;
import java.util.concurrent.atomic.AtomicInteger;

@Named
@ApplicationScoped
public class AMQHealthCheck extends HealthCheck {

  private static final Logger logger = LoggerFactory.getLogger(AMQHealthCheck.class);

  private static AtomicInteger MESSAGES_SENT = new AtomicInteger(0) ;

  @Resource(mappedName = "java:/ConnectionFactory")
  private ConnectionFactory connectionFactory;

  @Resource(mappedName = "java:/queue/ODIEMDBQueue")
  private Queue queue;

  public AMQHealthCheck() {
    logger.info("Initializing AMQHealthCheck");
    ODIEHealthCheckServletContextListener.HEALTH_CHECK_REGISTRY.register("broker", this);
  }

  @Override
  protected Result check() throws Exception {
    try {
      if (checkHealth()) {
        return Result.healthy();
      } else {
        return Result.unhealthy("AMQ Message sent / received counts are not the same");
      }
    }
    catch (Exception e) {
      e.printStackTrace();
      return Result.unhealthy("Failure: " + e.getMessage() );
    }
  }

  public boolean checkHealth() {
    sendMessage(queue, "", 5);
    return checkExpectedMessageCount();
  }

  public boolean checkExpectedMessageCount() {
    try {
      Thread.sleep(100);
    }
    catch (InterruptedException e) {
      throw new BrokerException(e);
    }
    return MESSAGES_SENT.get() == ODIEQueueMDB.MESSAGES_RECEIVED.get();
  }

  private void sendMessage(Destination destination, String messageUUID, int numMessages) {
    Connection connection = null;
    try {
      connection = connectionFactory.createConnection();
      Session session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
      MessageProducer messageProducer = session.createProducer(destination);
      connection.start();

      TextMessage message = session.createTextMessage();
      for (int i = 1; i <= numMessages; i++) {
        message.setText("This is message " + messageUUID + (i));
        messageProducer.send(message);
        MESSAGES_SENT.incrementAndGet();
      }

    } catch (JMSException e) {
      logger.error(e.toString());
      throw new BrokerException(e);
    } finally {
      if (connection != null) {
        try {
          connection.close();
        } catch (JMSException e) {
          e.printStackTrace();
        }
      }
    }
  }
}
