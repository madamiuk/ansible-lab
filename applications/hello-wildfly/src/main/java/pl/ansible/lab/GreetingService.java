package pl.ansible.lab;

import jakarta.ejb.Stateless;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.time.OffsetDateTime;

import java.util.List;

@Stateless
public class GreetingService {

    @PersistenceContext(unitName = "ansibleLabPU")
    private EntityManager entityManager;

    public String getGreeting() {
        return "Hello from a Stateless EJB!";
    }

    public List<AppData> findAllAppData() {
        return entityManager
                .createQuery(
                        "SELECT a FROM AppData a ORDER BY a.id",
                        AppData.class
                )
                .getResultList();
    }

    public AppData createAppData(String hostname) {
        AppData appData = new AppData(hostname, OffsetDateTime.now());
        entityManager.persist(appData);
        return appData;
    }

}
