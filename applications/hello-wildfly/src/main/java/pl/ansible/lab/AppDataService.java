package pl.ansible.lab;

import jakarta.ejb.Stateless;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import java.time.OffsetDateTime;
import java.util.List;

import pl.ansible.lab.dto.AppDataDto;

@Stateless
public class AppDataService {

    @PersistenceContext(unitName = "ansibleLabPU")
    private EntityManager entityManager;

    public List<AppDataDto> findAll() {
        return entityManager
                .createQuery(
                        "SELECT a FROM AppData a ORDER BY a.id",
                        AppData.class
                )
                .getResultList()
                .stream()
                .map(this::toDto)
                .toList();
    }

    public AppDataDto create(String hostname) {
        AppData appData = new AppData(hostname, OffsetDateTime.now());
        entityManager.persist(appData);
        return toDto(appData);
    }

    private AppDataDto toDto(AppData appData) {
        return new AppDataDto(
                appData.getId(),
                appData.getHostname(),
                appData.getCreatedAt()
        );
    }
}
