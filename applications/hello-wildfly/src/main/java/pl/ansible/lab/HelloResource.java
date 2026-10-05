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
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.PUT;
import pl.ansible.lab.dto.AppDataCreateDto;
import jakarta.validation.Valid;

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

    @GET
    @Path("/data/{id}")
    @Produces(MediaType.APPLICATION_JSON)
    public AppDataDto getData(@PathParam("id") Long id) {
        AppDataDto appData = appDataService.findById(id);

        if (appData == null) {
            throw new NotFoundException("Nie znaleziono AppData o id=" + id);
        }

        return appData;
    }

    @PUT
    @Path("/data/{id}")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public AppDataDto updateData(
            @PathParam("id") Long id,
            @Valid AppDataCreateDto request) {

        AppDataDto appData = appDataService.update(id, request.getHostname());

        if (appData == null) {
            throw new NotFoundException("Nie znaleziono AppData o id=" + id);
        }

        return appData;
    }
    @DELETE
    @Path("/data/{id}")
    public void deleteData(@PathParam("id") Long id) {
        if (!appDataService.delete(id)) {
            throw new NotFoundException("Nie znaleziono AppData o id=" + id);
        }
    }

}
