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
import pl.ansible.lab.dto.AppDataDto;
import jakarta.ws.rs.BadRequestException;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

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
    public List<AppDataDto> data() {
        return appDataService.findAll();
    }

    @POST
    @Path("/data")
    @Produces(MediaType.APPLICATION_JSON)
    public AppDataDto createData(
        @QueryParam("hostname")
        @NotBlank(message = "hostname jest wymagany")
        @Size(max = 253, message = "hostname może mieć maksymalnie 253 znaki")
        @Pattern(
                regexp = "^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$",
                message = "hostname zawiera niedozwolone znaki"
        )
        String hostname) {

    return appDataService.create(hostname);
    }
}
