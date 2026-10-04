package pl.ansible.lab;

import jakarta.ejb.EJB;
import jakarta.enterprise.context.RequestScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.QueryParam;
import java.util.List;

@RequestScoped
@Path("/hello")
public class HelloResource {

    @EJB
    private GreetingService greetingService;

    @EJB
    private AppDataService appDataService;

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return greetingService.getGreeting();
    }

    @GET
    @Path("/data")
    @Produces(MediaType.APPLICATION_JSON)
    public List<AppData> data() {
        return appDataService.findAll();
    }

    @POST
    @Path("/data")
    @Produces(MediaType.APPLICATION_JSON)
    public AppData createData(@QueryParam("hostname") String hostname) {
        if (hostname == null || hostname.isBlank()) {
            throw new IllegalArgumentException("Brak parametru hostname");
        }

        return appDataService.create(hostname);
    }

}
