package pl.ansible.lab;

import jakarta.ejb.Stateless;

@Stateless
public class GreetingService {

    public String getGreeting() {
        return "Hello from a Stateless EJB!";
    }
}
