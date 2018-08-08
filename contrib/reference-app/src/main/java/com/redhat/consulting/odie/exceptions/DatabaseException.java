package com.redhat.consulting.odie.exceptions;

public class DatabaseException extends  RuntimeException {
  public DatabaseException(Exception e) {
    super(e);
  }
}
