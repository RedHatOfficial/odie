package com.redhat.consulting.odie.exceptions;

public class BrokerException extends RuntimeException {
  public  BrokerException(Exception e) {
    super(e);
  }
}
