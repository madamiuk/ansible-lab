package pl.ansible.lab;

import jakarta.ejb.EJB;
import jakarta.enterprise.context.RequestScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@RequestScoped
@Path("/hello")
public class HelloResource {

    @EJB
    private GreetingService greetingService;

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return greetingService.getGreeting();
    }

    @GET
    @Path("/data")
    @Produces(MediaType.TEXT_PLAIN)
    public String data() {
        return greetingService.findAllAppData()
                .stream()
                .map(appData -> String.format(
                        "id=%d, hostname=%s, created_at=%s",
                        appData.getId(),
                        appData.getHostname(),
                        appData.getCreatedAt()
                ))
                .reduce((first, second) -> first + System.lineSeparator() + second)
                .orElse("Brak danych");
    }
}
